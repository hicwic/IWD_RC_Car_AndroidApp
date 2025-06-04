import 'dart:convert';
import 'dart:typed_data';

class TLVWriter {
  final List<int> _buffer = [];

  void begin(int msgType, int dataType) {
    _buffer.add(msgType);
    _buffer.add(dataType);
  }

  void addUint8(int id, int value) {
    _buffer.add(id);
    _buffer.add(1);
    _buffer.add(value & 0xFF);
  }

  void addInt8(int id, int value) {
    final b = ByteData(1)..setInt8(0, value);
    _buffer.add(id);
    _buffer.add(1);
    _buffer.add(b.getInt8(0));
  }

  void addBool(int id, bool value) => addUint8(id, value ? 1 : 0);

  void addEnum(int id, int index) => addUint8(id, index);

  void addString(int id, String value) {
    final bytes = utf8.encode(value);
    _buffer.add(id);
    _buffer.add(bytes.length);
    _buffer.addAll(bytes);
  }

  void addInt32(int id, int value) {
    final bytes = ByteData(4)..setInt32(0, value, Endian.little);
    _buffer.add(id);
    _buffer.add(4);
    _buffer.addAll(bytes.buffer.asUint8List());
  }

  void addInt64(int id, int value) {
    final bytes = ByteData(8)..setInt64(0, value, Endian.little);
    _buffer.add(id);
    _buffer.add(8);
    _buffer.addAll(bytes.buffer.asUint8List());
  }

  void addDouble(int id, double value) {
    final bytes = ByteData(8)..setFloat64(0, value, Endian.little);
    _buffer.add(id);
    _buffer.add(8);
    _buffer.addAll(bytes.buffer.asUint8List());
  }

  Uint8List toBytes() => Uint8List.fromList(_buffer);
}

class TLVReader {
  final Uint8List data;
  int _index = 2;

  TLVReader(this.data);

  bool isValid(int expectedMsgType, int expectedDataType) {
    return data.length >= 2 &&
          data[0] == expectedMsgType &&
          data[1] == expectedDataType;
  }

  bool get done => _index >= data.length;

  ({int id, Uint8List value})? next() {
    if (_index + 2 > data.length) return null;
    final id = data[_index++];
    final length = data[_index++];
    if (_index + length > data.length) return null;
    final value = data.sublist(_index, _index + length);
    _index += length;
    return (id: id, value: Uint8List.fromList(value));
  }

  static int readUint8(Uint8List bytes) => bytes[0];

  static int readInt8(Uint8List bytes) =>
      ByteData.sublistView(bytes).getInt8(0);

  static bool readBool(Uint8List bytes) => bytes[0] != 0;

  static String readString(Uint8List bytes) => utf8.decode(bytes);

  static int readInt32(Uint8List bytes) =>
      ByteData.sublistView(bytes).getInt32(0, Endian.little);

  static int readInt64(Uint8List bytes) =>
      ByteData.sublistView(bytes).getInt64(0, Endian.little);

  static double readDouble(Uint8List bytes) =>
      ByteData.sublistView(bytes).getFloat64(0, Endian.little);
}
