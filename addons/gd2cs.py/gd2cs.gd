tool
extends EditorPlugin

var popup:WindowDialog
var file_dialogue
var input_list : VBoxContainer
var python_executable : LineEdit
var output_pattern_A : LineEdit
var output_pattern_B : LineEdit
var output_to_pascal : CheckButton

var enabled = false;


func get_files_container():
	return popup.get_node("VBoxContainer/TopBottomSplit/LeftRightSplit/Panel_L/Files/Files");
	
func get_regex_container(): 
	return  popup.get_node("VBoxContainer/TopBottomSplit/LeftRightSplit/Panel_R/NameRepl/NameReplace");

func get_console():
	return popup.get_node("VBoxContainer/TopBottomSplit/Console/ScrollContainer/VBoxContainer")

func print_to_console(text:String,color:Color = Color.white)->Label:
	var line = Label.new()
	line.text = text;  
	line.self_modulate = color;
	 
	get_console().add_child(line)
	return line 
	

# TODO : Find FileSystem's context meny by searching for its default elements
#func search(node:Node):
#	if ('text' in node and 'to Favorites' in node.text or 
#	'label' in node and 'to Favorites' in node.label) and not 'TextEdit' in str(node.get_path()):
#		print(node.get_path())
#
#
#	for child in node.get_children():
#		search(child)
#

	
# Process the actual conversion
func do_conversion():
	var output = [];
	var files = get_files()
	var executable = popup.find_node('PythonExecutable').text
	var remove_res = RegEx.new()
	remove_res.compile("^res://")
	for file in files:
		
		if ProjectSettings.globalize_path(file[0]) == ProjectSettings.globalize_path(file[1]):
			print_to_console("Error: Input file path is equivalent to output file path. " + file[0] + " . SKIPPED!",Color.red)
			continue 
		
		file[0] = remove_res.sub(file[0],"")
		file[1] = remove_res.sub(file[1],"")
		
		var return_code = OS.execute(executable, ["addons/plugin/gd2cs.py","-i",file[0],"-o",file[1]],true,output)
		if return_code != 0 : 
			print_to_console("ERROR : Python exited with code " + str(return_code), Color.red)
		for out in output:
			print_to_console(out+"\n")
		get_editor_interface().get_resource_filesystem().update_file(file[1])
		

# Read the files from the files list as an array of [input_path,output_path,node in list]
func get_files()->Array:
	var result = []
	var input_list = get_files_container()
	for node in input_list.get_children():
		var input = node.find_node("Input").text;
		var output = node.find_node("Output").text;
		result.append([input,output,node])
	return result;
		
func files_selected(values):
	print(values);

# Prompt the user to select gd files
func select_files()->Array:
	var file_dialogue = popup.find_node("EditorFileDialog");
	file_dialogue.popup_centered()
	var result = yield(file_dialogue,"files_selected");
	return result;

# Turn input name to output name
func input_to_output(input:String)->String:
	var name_replace = get_regex_container()
	for child in name_replace.get_children():
		var r = RegEx.new()
		
		
		r.compile(child.find_node("ReplaceMatch").text);
		input = r.sub(input,child.find_node("ReplaceSub").text,true);
	return input

# Prompt the user to select input files and create the matching ui elements once the files were submitted
func add_input():
	var result = yield(select_files(),"completed")
	var inputs_list = get_files_container()
	for child in result:
		var child_node : Node = load("res://addons/plugin/scenes/FileElement.tscn").instance()
		child_node.find_node("Input").text = child
		child_node.find_node("Output").text = input_to_output(child)
		#child_node.find_node("RemoveButton").connect("button_up",self,"remove_input",[child_node])
		inputs_list.add_child(child_node);
		
func add_rename_rule():
	var rename_list = get_regex_container();
	var child_node : Node = load("res://addons/plugin/scenes/ReplaceElement.tscn").instance();
	rename_list.add_child(child_node);
		
func reset_outputs():
	var files = get_files()
	for file in files:
		var node = file[2];
		node.find_node("Output").text = file[0]
	
	
	
func rename_all():
	var files = get_files()
	for file in files:
		var node = file[2];
		node.find_node("Output").text = input_to_output(file[1])


# Check all common path aliases for the python executable. Prefer python3 over python2.
func get_best_python_exec():

	if ProjectSettings.has_setting("gd2cs/config/python"):
		var exec = ProjectSettings.get_setting("gd2cs/config/python")
		if not exec in ["null",""]:
			return exec;
	
	var output = [];
	var options = ["py","python3","python","python2"];
	for option in options:
		if OS.execute(option,["--version"],true,output) == 0:
			ProjectSettings.set_setting("gd2cs/config/python",option)
			return option
	
	print_to_console("No valid python install could be detected.",Color.red)
	
	if ProjectSettings.get_setting("gd2cs/config/ask_no_python"):
		popup.find_node("NoPythonDialog").popup_centered(Vector2(400,400));
	
	return "#NO PYTHON FOUND#" # No installed python env found

func change_python_exec(val):
	ProjectSettings.set_setting("gd2cs/config/python",val)

func set_ask_no_python(val):
	ProjectSettings.set_setting("gd2cs/config/ask_no_python",not val)

func download_python():
	OS.shell_open("https://www.python.org/downloads/")
	popup.find_node("NoPythonDialog").hide()	
	popup.hide()
	

func callback(ud):  
	if not popup : 
		popup = load("res://addons/plugin/scenes/Editor_UI.tscn").instance();
		add_child(popup)
		popup.find_node("EditorFileDialog").add_filter("*.gd") 
		popup.find_node("SelectInput").connect("pressed",self,"add_input")
		popup.find_node("AddRR").connect("pressed",self,"add_rename_rule")
		popup.find_node('PythonExecutable').connect("text_changed",self,"change_python_exec")
		popup.find_node("ConvertButton").connect("button_up",self,"do_conversion")		
		popup.find_node("ResetNames").connect("pressed",self,"reset_outputs")		
		popup.find_node("ApplyRename").connect("pressed",self,"rename_all")		
		popup.find_node("DontAskAgain").connect("toggled",self,"set_ask_no_python")		
		popup.find_node("DownloadPython").connect("pressed",self,"download_python")		
		print_to_console("Console Initialized") 
	
	popup.find_node('PythonExecutable').text = get_best_python_exec()
	popup.popup_centered(Vector2(800,600));
	
func _enter_tree():
	enabled = true;
	if not ProjectSettings.has_setting("gd2cs/config/ask_no_python"):
		ProjectSettings.set_setting("gd2cs/config/ask_no_python",true)
	add_tool_menu_item("gd2cs", self, "callback")
	
	
func _exit_tree():
	enabled = false;
	remove_tool_menu_item("gd2cs")
