extends Node

func get_entries(_score: int = 0) -> Array:
	return await SupabaseClient.fetch_top10()

func estimate_rank(_score: int) -> int:
	return 0
