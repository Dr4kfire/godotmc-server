## Base class for all packet resources

@icon("uid://b4y87s026solw") ## chest.png
class_name Packet
extends Resource

enum FIELD_NAMES {
	LENGTH = MCTypes.VARINT,
	ID = MCTypes.UNSIGNED_SHORT,
	DATA,
	}

@export var raw_packet: PackedByteArray = []
@export var fields: Dictionary[FIELD_NAMES, Variant]


static func decode_packet(raw: PackedByteArray) -> Packet:
	var len_decode := MCTypes.decode_varint(raw, 0)
	if len_decode.error != OK:
		return null
	
	var new_packet: Packet = Packet.new()
	new_packet.fields = {
		FIELD_NAMES.LENGTH: len_decode.value,
		FIELD_NAMES.ID: raw.decode_u8(len_decode.byte_length),
		FIELD_NAMES.DATA: raw.slice(len_decode.byte_length+1),
		}
	return new_packet

enum PACKET_IDS {
	STATUS = 0x00,
	PING = 0x01,
	}
