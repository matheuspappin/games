# =============================================================================
# room_code_helper.gd
# Utilitário de Geração e Decodificação de Códigos de Sala estilo Call of Duty
# Suporta:
# - Codificação inteligente de IP (IPv4) e Porta em formato amigável (ex: NK-C0A8010F)
# - Decodificação automática aceitando: Códigos 'NK-XXXX', IPs diretos ('127.0.0.1:7777')
# - Descoberta de IP local (LAN) e IP público via UPnP nativo do Godot 4
# =============================================================================
class_name RoomCodeHelper
extends RefCounted

const DEFAULT_PORT: int = 7777
const PREFIX: String = "NK"

## Converte um IP (IPv4) e porta em um código amigável de sala (ex: NK-C0A8-010F)
static func encode_room_code(ip: String, port: int = DEFAULT_PORT) -> String:
	var clean_ip = ip.strip_edges()
	if clean_ip.is_empty() or clean_ip == "127.0.0.1" or clean_ip == "localhost":
		# Código especial para testes locais
		return "%s-LOCAL-%04d" % [PREFIX, (port % 10000)]

	var parts = clean_ip.split(".")
	if parts.size() != 4:
		# Fallback se não for IPv4 padrão
		var b64 = Marshalls.utf8_to_base64("%s:%d" % [clean_ip, port]).replace("=", "").replace("/", "_").replace("+", "-")
		return "%s-%s" % [PREFIX, b64]

	var b0 = parts[0].to_int() & 0xFF
	var b1 = parts[1].to_int() & 0xFF
	var b2 = parts[2].to_int() & 0xFF
	var b3 = parts[3].to_int() & 0xFF

	var hex_ip = "%02X%02X%02X%02X" % [b0, b1, b2, b3]
	
	if port == DEFAULT_PORT:
		return "%s-%s" % [PREFIX, hex_ip]
	else:
		return "%s-%s-%X" % [PREFIX, hex_ip, port]

## Decodifica um código de sala ou string digitada pelo usuário em um Dicionário {valid, ip, port, error}
static func decode_room_code(input: String) -> Dictionary:
	var raw = input.strip_edges()
	if raw.is_empty():
		return {"valid": false, "ip": "127.0.0.1", "port": DEFAULT_PORT, "error": "Código vazio."}

	# 0. host:porta explícito (ex.: localhost:8090, jogo.exemplo.com:443) — servidor dedicado via Caddy
	var hp := raw.rsplit(":", true, 1)
	if hp.size() == 2 and hp[1].strip_edges().is_valid_int() and not hp[0].is_empty() and not raw.to_upper().begins_with("NK-"):
		return {"valid": true, "ip": hp[0].strip_edges(), "port": hp[1].strip_edges().to_int(), "error": ""}

	# 1. Se for palavra-chave LOCAL
	if raw.to_upper().contains("LOCAL") or raw.to_upper().contains("DEV"):
		var p = DEFAULT_PORT
		var subparts = raw.split("-")
		if subparts.size() >= 3 and subparts[2].is_valid_int():
			p = subparts[2].to_int()
		return {"valid": true, "ip": "127.0.0.1", "port": p, "error": ""}

	# 2. Se for IP direto com ou sem porta (ex: 192.168.1.15 ou 142.93.120.45:7777)
	if raw.contains("."):
		var splitted = raw.split(":")
		var ip_candidate = splitted[0].strip_edges()
		var port_candidate = DEFAULT_PORT
		if splitted.size() > 1 and splitted[1].strip_edges().is_valid_int():
			port_candidate = splitted[1].strip_edges().to_int()

		var octets = ip_candidate.split(".")
		if octets.size() == 4:
			var valid_octets = true
			for oc in octets:
				if not oc.is_valid_int() or oc.to_int() < 0 or oc.to_int() > 255:
					valid_octets = false
					break
			if valid_octets:
				return {"valid": true, "ip": ip_candidate, "port": port_candidate, "error": ""}

	# 3. Se for código formatado (ex: NK-C0A8010F ou NK-C0A8010F-1E61)
	var clean = raw.to_upper().replace(" ", "").replace("_", "-")
	var tokens = clean.split("-")

	# Remover prefixo se houver (NK ou COD)
	var hex_body = ""
	var port_hex = ""
	if tokens.size() >= 2:
		hex_body = tokens[1]
		if tokens.size() >= 3:
			port_hex = tokens[2]
	else:
		hex_body = tokens[0]

	# Checar se hex_body tem 8 caracteres hexadecimais (4 bytes de IP)
	if hex_body.length() == 8:
		var is_hex = true
		for ch in hex_body:
			if not (ch in "0123456789ABCDEF"):
				is_hex = false
				break
		if is_hex:
			var b0 = ("0x" + hex_body.substr(0, 2)).hex_to_int()
			var b1 = ("0x" + hex_body.substr(2, 2)).hex_to_int()
			var b2 = ("0x" + hex_body.substr(4, 2)).hex_to_int()
			var b3 = ("0x" + hex_body.substr(6, 2)).hex_to_int()
			var parsed_ip = "%d.%d.%d.%d" % [b0, b1, b2, b3]

			var parsed_port = DEFAULT_PORT
			if not port_hex.is_empty():
				if port_hex.is_valid_int():
					parsed_port = port_hex.to_int()
				else:
					parsed_port = ("0x" + port_hex).hex_to_int()

			return {"valid": true, "ip": parsed_ip, "port": parsed_port, "error": ""}

	# 4. Tentar decodificar como base64
	var b64_clean = raw
	if tokens.size() >= 2:
		b64_clean = tokens[1]
	var decoded_str = Marshalls.base64_to_utf8(b64_clean.replace("-", "+").replace("_", "/"))
	if decoded_str.contains("."):
		var splitted_b64 = decoded_str.split(":")
		var ip_val = splitted_b64[0]
		var port_val = splitted_b64[1].to_int() if splitted_b64.size() > 1 else DEFAULT_PORT
		return {"valid": true, "ip": ip_val, "port": port_val, "error": ""}

	return {"valid": false, "ip": "127.0.0.1", "port": DEFAULT_PORT, "error": "Formato de código inválido."}

## Obtém o IP da rede local (LAN) mais apropriado (ignora 127.0.0.1)
static func get_local_lan_ip() -> String:
	var addresses = IP.get_local_addresses()
	for addr in addresses:
		# Filtra apenas IPv4 privados válidos (ex: 192.168.x.x, 10.x.x.x, 172.16.x.x)
		if addr.contains(".") and not addr.begins_with("127.") and not addr.begins_with("169.254."):
			if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
				return addr
	for addr in addresses:
		if addr.contains(".") and not addr.begins_with("127."):
			return addr
	return "127.0.0.1"

## Tenta abrir a porta no roteador automaticamente usando UPnP do Godot 4
static func try_setup_upnp(port: int = DEFAULT_PORT) -> Dictionary:
	var upnp = UPNP.new()
	var discover_err = upnp.discover(2000, 2, "InternetGatewayDevice")
	if discover_err != UPNP.UPNP_RESULT_SUCCESS:
		# Tentar descoberta genérica
		discover_err = upnp.discover()

	if discover_err == UPNP.UPNP_RESULT_SUCCESS:
		var gateway = upnp.get_gateway()
		if gateway and gateway.is_valid_gateway():
			var map_err = upnp.add_port_mapping(port, port, "NUKE_1v1_Tactical", "UDP")
			if map_err == UPNP.UPNP_RESULT_SUCCESS or map_err == UPNP.UPNP_RESULT_SAME_PORT_VALUES_REQUIRED:
				var ext_ip = upnp.query_external_address()
				if not ext_ip.is_empty() and ext_ip != "0.0.0.0":
					print("[RoomCodeHelper] UPnP ativo com sucesso! Porta UDP %d mapeada. IP Externo: %s" % [port, ext_ip])
					return {
						"success": true,
						"external_ip": ext_ip,
						"port": port,
						"gateway": gateway.get_gateway_name()
					}

	print("[RoomCodeHelper] UPnP indisponível no roteador. Utilizando fallback LAN / IP local.")
	return {
		"success": false,
		"external_ip": "",
		"port": port,
		"gateway": ""
	}
