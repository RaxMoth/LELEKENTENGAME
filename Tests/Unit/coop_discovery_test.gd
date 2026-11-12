## Unit tests for CoopDiscovery: the local-network announcement and the
## addresses players type to join.
##
## Dependencies: gdUnit4
extends GdUnitTestSuite


func test_an_announcement_survives_the_round_trip() -> void:
	var game: Dictionary = CoopDiscovery.parse(CoopDiscovery.encode("Max's house", 7777, 3))
	assert_str(str(game[CoopDiscovery.KEY_NAME])).is_equal("Max's house")
	assert_int(int(game[CoopDiscovery.KEY_PORT])).is_equal(7777)
	assert_int(int(game[CoopDiscovery.KEY_PROTOCOL])).is_equal(3)


func test_other_packets_are_ignored() -> void:
	assert_bool(CoopDiscovery.parse("hello".to_utf8_buffer()).is_empty()).is_true()
	assert_bool(CoopDiscovery.parse(JSON.stringify({"game": "other", "port": 7777}).to_utf8_buffer()).is_empty()).is_true()
	assert_bool(CoopDiscovery.parse(JSON.stringify({"game": CoopDiscovery.GAME_ID, "port": 70000}).to_utf8_buffer()).is_empty()).is_true()


func test_long_names_are_cut() -> void:
	var game: Dictionary = CoopDiscovery.parse(CoopDiscovery.encode("x".repeat(100), 7777, 1))
	assert_int(str(game[CoopDiscovery.KEY_NAME]).length()).is_equal(CoopDiscovery.MAX_NAME_LENGTH)


func test_addresses_split_into_host_and_port() -> void:
	assert_array(CoopDiscovery.split_address("203.0.113.5:9000", 7777)).is_equal(["203.0.113.5", 9000])
	assert_array(CoopDiscovery.split_address(" 192.168.1.20 ", 7777)).is_equal(["192.168.1.20", 7777])
	assert_array(CoopDiscovery.split_address("[2001:db8::1]:9000", 7777)).is_equal(["2001:db8::1", 9000])
	assert_array(CoopDiscovery.split_address("2001:db8::1", 7777)).is_equal(["2001:db8::1", 7777])


func test_only_plausible_addresses_can_be_joined() -> void:
	assert_bool(CoopDiscovery.is_valid_address("203.0.113.5:7777")).is_true()
	assert_bool(CoopDiscovery.is_valid_address("myhouse.example.com")).is_true()
	assert_bool(CoopDiscovery.is_valid_address("")).is_false()
	assert_bool(CoopDiscovery.is_valid_address(":7777")).is_false()
