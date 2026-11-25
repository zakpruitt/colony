class_name QuestLine
extends Resource
## One line a quest's story may say ([member QuestDef.lines]): at which beat, by whom, for which
## class, and its words. The view picks one of the lines that fit at random each time.

## The beats of a quest's story, and who may say a line.
const BEATS: Array[StringName] = [&"plea", &"arrive", &"work", &"watch", &"done", &"thanks"]
const SPEAKERS: Array[StringName] = [&"subject", &"worker", &"watcher"]
## The most characters a line may have: a bubble holds it on one or two lines.
const MOST_CHARACTERS: int = 48

@export var beat: StringName  # plea, arrive, work, watch, done, thanks
@export var speaker: StringName  # subject, worker, watcher
@export var class_id: StringName  # &"" for any class
@export var text: String
