## Used for converting PackedByteArrays into Godot readable
## types and Godot types into PackedByteArrays
##
## look at https://minecraft.wiki/w/Java_Edition_protocol/Packets
## for more info

@icon("uid://ceieefi4pf28n") ## knowledge_book
@abstract
class_name MCTypes
extends Minecraft


enum { ## TYPES
	BYTE = 1,                ## INT8
	UNSIGNED_BYTE = BYTE,    ## UNSIGNED INT8
	BOOLEAN = BYTE,          ## INT8
	   
	SHORT = 2,               ## INT16
	UNSIGNED_SHORT = 2,      ## UNSIGNED INT16
	INT = 4,                 ## INT32
	LONG = 8,                ## INT64
	
	FLOAT = 4,               ## FLOAT (32 bit)
	DOUBLE = 8,              ## FLOAT (64 bit)
	
	STRING = 0,              ## 1..(n*3)+3
	TEXT_COMPONENT = -1,     ## VARIES
	JSON_TEXT_COMPONENT = 0, ## 1..32767
	
	VARINT = 0,              ## 1..5  INT32
	VARLONG = 0,             ## 1..10 INT64
	}



static func decode_boolean(packet: PackedByteArray, offset: int = 0) -> DecodeReturn:
	if _is_outside_of_range(packet, offset):
		return DecodeReturn.quick(ERR_FILE_EOF)
	var byte: int = packet.decode_u8(offset)
	if byte > 1:
		return DecodeReturn.quick(ERR_INVALID_DATA)
	return DecodeReturn.quick(OK, 1, type_convert(byte, TYPE_BOOL), TYPE_BOOL)


static func decode_varint(packet: PackedByteArray, offset: int = 0) -> DecodeReturn:
	const SEGMENT_MASK := 0x7f
	const CONTINUE_BIT := 0x80
	
	if _is_outside_of_range(packet, offset):
		return DecodeReturn.quick(ERR_FILE_EOF)
	
	var result: DecodeReturn = DecodeReturn.quick(OK, 0, 0, TYPE_INT)
	for position in range(0, 64, 7):
		var byte: int = packet.decode_u8(offset + floori(position/7.0))
		var unmasked_value := (byte & SEGMENT_MASK) << position
		result.value = result.value | unmasked_value
		if (byte & CONTINUE_BIT) == 0: 
			result.byte_length = floori(position/7.0)
			break
		
		if position + 7 >= 64:
			return DecodeReturn.quick(ERR_INVALID_DATA)
	return result


static func decode_varint_from_stream(stream: StreamPeerTCP) -> DecodeReturn:
	const SEGMENT_MASK := 0x7f
	const CONTINUE_BIT := 0x80
	
	if stream.get_available_bytes() < 1:
		return DecodeReturn.quick(ERR_UNAVAILABLE)
	
	var result: DecodeReturn = DecodeReturn.quick(OK, 0, 0, TYPE_INT)
	for position in range(0, 64, 7):
		var byte: int = stream.get_u8()
		var unmasked_value := (byte & SEGMENT_MASK) << position
		result.value = result.value | unmasked_value
		if (byte & CONTINUE_BIT) == 0: 
			result.byte_length = floori(position/7.0)+1
			break
		
		if position + 7 >= 64:
			return DecodeReturn.quick(ERR_INVALID_DATA)
	return result


static func decode_string(packet: PackedByteArray, offset: int = 0) -> DecodeReturn:
	var result: DecodeReturn = decode_varint(packet, offset)
	if result.error != OK:
		return DecodeReturn.quick(result.error)
	var string_bytes := packet.slice(offset + result.byte_length + 1)
	return DecodeReturn.quick(
		OK, result.byte_length+string_bytes.size(), 
		string_bytes.get_string_from_utf8(), TYPE_STRING)



## Returns a PackedByteArray
static func encode_boolean(value: bool) -> PackedByteArray:
	if value: return [0x01]
	return [0x00]

static func encode_varint(value: int) -> PackedByteArray:
	const SEGMENT_MASK := 0x7f
	const CONTINUE_BIT := 0x80
	var varint: PackedByteArray
	while true:
		if (value & ~SEGMENT_MASK) == 0:
			varint.append(value & 0xff) # mask to 8 bits (one byte)
			break
		varint.append((value & SEGMENT_MASK) | CONTINUE_BIT)
		value = _unsigned_right_shift(value, 7)
	return varint

static func encode_string(value: String) -> PackedByteArray:
	var str_buffer := value.to_utf8_buffer()
	var result := encode_varint(str_buffer.size())
	result.append_array(str_buffer)
	return result



static func _is_outside_of_range(array: Array, index: int) -> bool:
	return index >= array.size()

static func _unsigned_right_shift(value: int, shift_ammount: int) -> int:
	if value >= 0:
		return value >> shift_ammount
	var mask = (1 << (32 - shift_ammount)) - 1
	return (value >> shift_ammount) & mask


class DecodeReturn:
	var error: Error = ERR_UNCONFIGURED
	var byte_length: int = 0
	var value: Variant = null
	var value_type: Variant.Type = TYPE_NIL
	
	static func quick(_error: Error, _byte_length: int = 0, _value: Variant = null, 
	_value_type: Variant.Type = TYPE_NIL) -> DecodeReturn:
		var new: DecodeReturn = DecodeReturn.new()
		new.error = _error
		new.byte_length = _byte_length
		new.value = _value
		new.value_type = _value_type
		return new
