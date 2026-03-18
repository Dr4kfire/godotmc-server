@icon("uid://df88igcu7fbgg")
class_name ConnectionHandler
extends Minecraft

signal new_packet_received(packet: PackedByteArray)
signal connection_established
signal connection_closed

@export var server: MCTCPServerHandler
var current_connection: StreamPeerTCP
var packet_buffer: PackedByteArray = PackedByteArray()


func handle_connections() -> void:
	# Try to accept new connection if none exists
	if not current_connection:
		_try_accept_connection()
		return
	
	# Check connection health
	if not _is_connection_valid():
		_close_connection()
		_try_accept_connection()
		return
	
	current_connection.poll()
	
	# Skip if still connecting
	if current_connection.get_status() == StreamPeerTCP.STATUS_CONNECTING:
		return
	
	# Process all available packets
	_process_packets()


func _try_accept_connection() -> void:
	current_connection = server.server.take_connection()
	if current_connection:
		print("[INFO]: New connection accepted from ip: %s" % current_connection.get_connected_host())
		connection_established.emit()


func _is_connection_valid() -> bool:
	if not current_connection:
		return false
	
	var status = current_connection.get_status()
	return status in [StreamPeerTCP.STATUS_CONNECTED, StreamPeerTCP.STATUS_CONNECTING]


func _close_connection() -> void:
	if current_connection:
		current_connection.disconnect_from_host()
		current_connection = null
		connection_closed.emit()


func _process_packets() -> void:
	while current_connection.get_available_bytes() > 0 && current_connection:
		# Try to read packet length
		if packet_buffer.size() >= 1:
			continue
		
		var decode = MCTypes.decode_varint_from_stream(current_connection)
		if decode.error != OK:
			printerr("[ERROR]: Failed to decode packet length: %s" % error_string(decode.error))
			_close_connection()
			return
		
		var packet_length = decode.value
		var bytes_read = decode.byte_length
		
		# Check if we have the full packet
		var remaining_bytes = packet_length - bytes_read
		if current_connection.get_available_bytes() < remaining_bytes:
			return  # Wait for more data
		
		# Read packet body
		var packet_body_result = current_connection.get_partial_data(remaining_bytes)
		if packet_body_result[0] != OK:
			printerr("[ERROR]: Failed to read packet body: %s" % error_string(packet_body_result[0]))
			_close_connection()
			return
		
		# Emit complete packet (length VarInt + body)
		var complete_packet = MCTypes.encode_varint(packet_length)
		complete_packet.append_array(packet_body_result[1] as PackedByteArray)
		new_packet_received.emit(complete_packet)


func send_packet(packet: PackedByteArray) -> void:
	if not _is_connection_valid():
		printerr("[ERROR]: Cannot send packet - no active connection")
		return
	
	var error = current_connection.put_data(packet)
	if error != OK:
		printerr("[ERROR]: Failed to send packet: %s" % error_string(error))
		_close_connection()


func close_connection() -> void:
	_close_connection()
