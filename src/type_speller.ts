import type {
  ArrayType,
  Field,
  PrimitiveType,
  RecordKey,
  RecordLocation,
  ResolvedRecordRef,
  ResolvedType,
} from "skir-internal";
import { convertCase } from "skir-internal";
import { getTypeName, modulePathToAlias } from "./naming.js";

export class TypeSpeller {
  constructor(
    readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>,
    readonly currentModulePath: string,
  ) {}

  getMoonbitType(type: ResolvedType): string {
    switch (type.kind) {
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const typeName = getTypeName(recordLocation);
        if (recordLocation.modulePath === this.currentModulePath) {
          return typeName;
        }
        return `@${modulePathToAlias(recordLocation.modulePath)}.${typeName}`;
      }
      case "array": {
        const maybeWrapperType = this.getMoonbitKeyedArrayWrapperType(type);
        if (maybeWrapperType) {
          return maybeWrapperType;
        }
        const itemType = this.getMoonbitType(type.item);
        return `@client.Array[${itemType}]`;
      }
      case "optional": {
        const otherType = this.getMoonbitType(type.other);
        return `${otherType}?`;
      }
      case "primitive": {
        const { primitive } = type;
        switch (primitive) {
          case "bool":
            return "@client.Bool";
          case "int32":
            return "@client.Int";
          case "int64":
            return "@client.Int64";
          case "hash64":
            return "@client.UInt64";
          case "float32":
            return "@client.Float";
          case "float64":
            return "@client.Double";
          case "timestamp":
            return "@client.Timestamp";
          case "string":
            return "@client.String";
          case "bytes":
            return "@client.Bytes";
        }
      }
    }
  }

  getMoonbitFieldType(field: Field): string {
    const type = this.getRequiredFieldType(field);
    const moonbitType = this.getMoonbitType(type);
    if (field.isRecursive === "hard") {
      return `@client.Recursive[${moonbitType}]`;
    }
    return moonbitType;
  }

  getMoonbitFieldDefault(field: Field): string {
    if (field.isRecursive === "hard") {
      return "@client.recursive_default()";
    }
    return this.getMoonbitDefault(this.getRequiredFieldType(field));
  }

  getMoonbitDefault(type: ResolvedType): string {
    switch (type.kind) {
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const typeName = getTypeName(recordLocation);
        const defaultMethod =
          recordLocation.record.recordType === "enum" ? "unknown" : "default";
        const defaultExpr = `${typeName}::${defaultMethod}()`;
        if (recordLocation.modulePath === this.currentModulePath) {
          return defaultExpr;
        }
        return `@${modulePathToAlias(recordLocation.modulePath)}.${defaultExpr}`;
      }
      case "array": {
        const maybeWrapperType = this.getMoonbitKeyedArrayWrapperType(type);
        if (maybeWrapperType) {
          return `${maybeWrapperType}::empty()`;
        }
        return "@client.Array::new()";
      }
      case "optional":
        return "None";
      case "primitive": {
        const { primitive } = type;
        switch (primitive) {
          case "bool":
            return "false";
          case "int32":
            return "0";
          case "int64":
            return "0L";
          case "hash64":
            return "0UL";
          case "float32":
          case "float64":
            return "0.0";
          case "timestamp":
            return "@client.timestamp_default()";
          case "string":
            return '""';
          case "bytes":
            return "Bytes::default()";
        }
      }
    }
  }

  private getRequiredFieldType(field: Field): ResolvedType {
    if (!field.type) {
      throw new Error("Expected field.type to be defined");
    }
    return field.type;
  }

  private getMoonbitKeyedArrayWrapperType(type: ArrayType): string | null {
    if (!type.key || type.item.kind !== "record") {
      return null;
    }
    if (!this.keyTypeIsSupported(type.key.keyType)) {
      return null;
    }

    const itemRecordLocation = this.recordMap.get(type.item.key)!;
    const itemTypeName = getTypeName(itemRecordLocation);
    const suffix = "_by".concat(
      type.key.path
        .map((p) => convertCase(p.name.text, "UpperCamel"))
        .join("_"),
    );
    const wrapperTypeName = `${itemTypeName}${suffix}`;
    if (itemRecordLocation.modulePath === this.currentModulePath) {
      return wrapperTypeName;
    }
    return `@${modulePathToAlias(itemRecordLocation.modulePath)}.${wrapperTypeName}`;
  }

  private keyTypeIsSupported(
    keyType: PrimitiveType | ResolvedRecordRef,
  ): boolean {
    return (
      keyType.kind === "record" ||
      (keyType.primitive !== "float32" &&
        keyType.primitive !== "float64" &&
        keyType.primitive !== "bytes")
    );
  }
}
