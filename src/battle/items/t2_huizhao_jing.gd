extends ItemEffect


func hostile_item_counter_charges(data: ItemData) -> int:
	return int(data.params.get("charges", 1))
