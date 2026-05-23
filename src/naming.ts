import { convertCase, type RecordLocation } from "skir-internal";

export function modulePathToPackageDir(modulePath: string): string {
  return modulePath.replace(/\.skir$/, "");
}

export function modulePathToFileStem(modulePath: string): string {
  return modulePath.replace(/^.*\//, "").replace(/\.skir$/, "");
}

export function modulePathToAlias(modulePath: string): string {
  return modulePathToPackageDir(modulePath)
    .replace(/[^a-zA-Z0-9]/g, "_")
    .replace(/^_+/, "")
    .concat("_skir");
}

export function getTypeName(record: RecordLocation): string {
  return record.recordAncestors
    .map((r) => escapeTypeName(r.name.text))
    .join("_");
}

export function toStructFieldName(name: string): string {
  let candidate = name;
  while (isReservedIdentifier(candidate) || candidate === "_unrecognized") {
    candidate = `${candidate}_`;
  }
  return candidate;
}

export function toEnumVariantName(
  name: string,
  usedNames: ReadonlySet<string>,
): string {
  let candidate = escapeTypeName(convertCase(name, "UpperCamel"));
  while (usedNames.has(candidate)) {
    candidate = `${candidate}_`;
  }
  return candidate;
}

function escapeTypeName(name: string): string {
  let candidate = name;
  while (isReservedIdentifier(candidate)) {
    candidate = `${candidate}_`;
  }
  return candidate;
}

function isReservedIdentifier(name: string): boolean {
  return RESERVED_IDENTIFIERS.has(name);
}

const RESERVED_IDENTIFIERS = new Set<string>([
  "and",
  "as",
  "break",
  "catch",
  "const",
  "continue",
  "derive",
  "else",
  "enum",
  "extern",
  "fn",
  "for",
  "guard",
  "if",
  "impl",
  "import",
  "in",
  "let",
  "loop",
  "match",
  "mut",
  "or",
  "priv",
  "pub",
  "raise",
  "return",
  "struct",
  "test",
  "trait",
  "try",
  "type",
  "typealias",
  "while",
  "with",
]);
