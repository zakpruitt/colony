extends ColonyTest
## Tests for specs/071-shared-test-base/spec.md: a save path goes with its backup and temporary
## files. That every test script reaches ColonyTest is held by the check's harness step.


func test_r2_a_save_path_is_removed_with_its_backups() -> void:
	var path: String = save_path("r2")
	var user_dir: String = OS.get_user_data_dir()
	assert_true(ProjectSettings.globalize_path(path).begins_with(user_dir), "under user: %s" % path)
	assert_true(path.contains(str(OS.get_process_id())), "named for this process: %s" % path)
	var files: Array[String] = [path, path + SaveStore.BACKUP_SUFFIX, path + SaveStore.TEMP_SUFFIX]
	for file_path: String in files:
		var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
		file.store_string("{}")
		file.close()
		assert_true(FileAccess.file_exists(file_path), "written: %s" % file_path)
	after_each()
	for file_path: String in files:
		assert_false(FileAccess.file_exists(file_path), "removed: %s" % file_path)
