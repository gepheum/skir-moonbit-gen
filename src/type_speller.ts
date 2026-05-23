import type { RecordKey, RecordLocation, ResolvedType } from "skir-internal";
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
}
