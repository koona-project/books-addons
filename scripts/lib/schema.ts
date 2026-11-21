export interface SchemaProblem {
  path: string;
  message: string;
}

type JsonSchema = Record<string, unknown>;

function resolveRef(root: JsonSchema, ref: string): JsonSchema {
  if (!ref.startsWith("#/")) {
    throw new Error(`Unsupported $ref: ${ref}`);
  }
  let cur: unknown = root;
  for (const part of ref.slice(2).split("/")) {
    const key = part.replace(/~1/g, "/").replace(/~0/g, "~");
    if (!cur || typeof cur !== "object" || !(key in (cur as Record<string, unknown>))) {
      throw new Error(`Unresolved $ref: ${ref}`);
    }
    cur = (cur as Record<string, unknown>)[key];
  }
  return cur as JsonSchema;
}

function deepEqual(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (typeof a !== typeof b || a === null || b === null) return false;
  if (Array.isArray(a) && Array.isArray(b)) {
    if (a.length !== b.length) return false;
    return a.every((v, i) => deepEqual(v, b[i]));
  }
  if (typeof a === "object" && typeof b === "object" && !Array.isArray(a) && !Array.isArray(b)) {
    const ka = Object.keys(a as Record<string, unknown>);
    const kb = Object.keys(b as Record<string, unknown>);
    if (ka.length !== kb.length) return false;
    return ka.every(
      (k) =>
        Object.prototype.hasOwnProperty.call(b, k) &&
        deepEqual((a as Record<string, unknown>)[k], (b as Record<string, unknown>)[k]),
    );
  }
  return false;
}

function matchesType(value: unknown, type: string): boolean {
  switch (type) {
    case "null":
      return value === null;
    case "boolean":
      return typeof value === "boolean";
    case "integer":
      return typeof value === "number" && Number.isInteger(value);
    case "number":
      return typeof value === "number" && Number.isFinite(value);
    case "string":
      return typeof value === "string";
    case "array":
      return Array.isArray(value);
    case "object":
      return value !== null && typeof value === "object" && !Array.isArray(value);
    default:
      return false;
  }
}

function checkNode(root: JsonSchema, schema: JsonSchema, value: unknown, path: string): SchemaProblem[] {
  const problems: SchemaProblem[] = [];

  if (typeof schema.$ref === "string") {
    problems.push(...checkNode(root, resolveRef(root, schema.$ref), value, path));
  }

  if (schema.type !== undefined) {
    const types = Array.isArray(schema.type) ? (schema.type as string[]) : [schema.type as string];
    if (!types.some((t) => matchesType(value, t))) {
      problems.push({ path: path || "$", message: `expected ${types.join(" or ")}` });
      return problems;
    }
  }

  if ("const" in schema && !deepEqual(value, schema.const)) {
    problems.push({ path: path || "$", message: `must equal ${JSON.stringify(schema.const)}` });
  }

  if (Array.isArray(schema.enum) && !schema.enum.some((item) => deepEqual(value, item))) {
    problems.push({ path: path || "$", message: `must be one of ${JSON.stringify(schema.enum)}` });
  }

  if (typeof value === "string") {
    const chars = [...value].length;
    if (typeof schema.minLength === "number" && chars < schema.minLength) {
      problems.push({ path: path || "$", message: `must be at least ${schema.minLength} characters` });
    }
    if (typeof schema.maxLength === "number" && chars > schema.maxLength) {
      problems.push({ path: path || "$", message: `must be at most ${schema.maxLength} characters` });
    }
    if (typeof schema.pattern === "string") {
      const re = new RegExp(schema.pattern, "u");
      if (!re.test(value)) {
        problems.push({ path: path || "$", message: `does not match pattern ${schema.pattern}` });
      }
    }
  }

  if (typeof value === "number") {
    if (typeof schema.minimum === "number" && value < schema.minimum) {
      problems.push({ path: path || "$", message: `must be >= ${schema.minimum}` });
    }
    if (typeof schema.maximum === "number" && value > schema.maximum) {
      problems.push({ path: path || "$", message: `must be <= ${schema.maximum}` });
    }
  }

  if (Array.isArray(value)) {
    if (typeof schema.minItems === "number" && value.length < schema.minItems) {
      problems.push({ path: path || "$", message: `must have at least ${schema.minItems} items` });
    }
    if (typeof schema.maxItems === "number" && value.length > schema.maxItems) {
      problems.push({ path: path || "$", message: `must have at most ${schema.maxItems} items` });
    }
    if (schema.uniqueItems === true) {
      for (let i = 0; i < value.length; i++) {
        for (let j = i + 1; j < value.length; j++) {
          if (deepEqual(value[i], value[j])) {
            problems.push({ path: `${path}[${j}]`, message: "duplicate item" });
            break;
          }
        }
      }
    }
    if (schema.items && typeof schema.items === "object" && !Array.isArray(schema.items)) {
      for (let i = 0; i < value.length; i++) {
        problems.push(...checkNode(root, schema.items as JsonSchema, value[i], `${path}[${i}]`));
      }
    }
    if (schema.contains && typeof schema.contains === "object") {
      const ok = value.some((item) => checkNode(root, schema.contains as JsonSchema, item, path).length === 0);
      if (!ok) {
        problems.push({ path: path || "$", message: "must contain a matching item" });
      }
    }
  }

  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    const obj = value as Record<string, unknown>;
    const keys = Object.keys(obj);
    if (typeof schema.minProperties === "number" && keys.length < schema.minProperties) {
      problems.push({ path: path || "$", message: `must have at least ${schema.minProperties} properties` });
    }
    if (typeof schema.maxProperties === "number" && keys.length > schema.maxProperties) {
      problems.push({ path: path || "$", message: `must have at most ${schema.maxProperties} properties` });
    }
    if (Array.isArray(schema.required)) {
      for (const req of schema.required as string[]) {
        if (!Object.prototype.hasOwnProperty.call(obj, req)) {
          problems.push({ path: path ? `${path}.${req}` : req, message: "is required" });
        }
      }
    }
    const props = (schema.properties ?? {}) as Record<string, JsonSchema>;
    if (schema.propertyNames && typeof schema.propertyNames === "object") {
      for (const key of keys) {
        problems.push(...checkNode(root, schema.propertyNames as JsonSchema, key, path ? `${path}.${key}` : key));
      }
    }
    for (const key of keys) {
      const childPath = path ? `${path}.${key}` : key;
      if (Object.prototype.hasOwnProperty.call(props, key)) {
        problems.push(...checkNode(root, props[key], obj[key], childPath));
      } else if (schema.additionalProperties === false) {
        problems.push({ path: childPath, message: "is not an allowed property" });
      } else if (schema.additionalProperties && typeof schema.additionalProperties === "object") {
        problems.push(...checkNode(root, schema.additionalProperties as JsonSchema, obj[key], childPath));
      }
    }
  }

  if (Array.isArray(schema.allOf)) {
    for (const sub of schema.allOf as JsonSchema[]) {
      problems.push(...checkNode(root, sub, value, path));
    }
  }

  if (Array.isArray(schema.anyOf)) {
    const results = (schema.anyOf as JsonSchema[]).map((sub) => checkNode(root, sub, value, path));
    if (!results.some((r) => r.length === 0)) {
      problems.push({ path: path || "$", message: "does not match any allowed schema" });
    }
  }

  if (schema.not && typeof schema.not === "object") {
    if (checkNode(root, schema.not as JsonSchema, value, path).length === 0) {
      problems.push({ path: path || "$", message: "must not match disallowed schema" });
    }
  }

  if (schema.if && typeof schema.if === "object") {
    const matchesIf = checkNode(root, schema.if as JsonSchema, value, path).length === 0;
    if (matchesIf && schema.then && typeof schema.then === "object") {
      problems.push(...checkNode(root, schema.then as JsonSchema, value, path));
    } else if (!matchesIf && schema.else && typeof schema.else === "object") {
      problems.push(...checkNode(root, schema.else as JsonSchema, value, path));
    }
  }

  return problems;
}

export function validateJsonSchema(schema: JsonSchema, value: unknown): SchemaProblem[] {
  return checkNode(schema, schema, value, "");
}
