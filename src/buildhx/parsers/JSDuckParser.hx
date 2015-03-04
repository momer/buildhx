package buildhx.parsers;


import buildhx.writers.HaxeExternWriter;
import sys.io.File;
import buildhx.data.ClassDefinition;
import buildhx.data.ClassMethod;
import buildhx.data.ClassProperty;


/**
 * ...
 * @author Joshua Granick
 */

class JSDuckParser extends SimpleParser {
	
	
	private var ignoredFiles:Array<String>;
	
	
	public function new (types:Map <String, String>, definitions:Map <String, ClassDefinition>) {
		
		super (types, definitions);
		
		if (definitions == null) {
			
			this.definitions = new Map <String, ClassDefinition> ();
			
		} else {
			
			this.definitions = definitions;
			
		}
		
		ignoredFiles = [ "globals.json" ];
		
		if (types == null) {
			
			types = new Map <String, String> ();
			
		}
		
		types.set ("String", "String");
		types.set ("Number", "Float");
		types.set ("Function", "Dynamic");
		types.set ("Boolean", "Bool");
		types.set ("Object", "Dynamic");
		types.set ("undefined", "Void");
		types.set ("null", "Void");
		types.set ("", "Dynamic");
		types.set ("HTMLElement", "HtmlDom");
		types.set ("Mixed", "Dynamic");
		types.set ("Iterable", "Dynamic");
		types.set ("Array", "Array<Dynamic>");
		types.set ("RegExp", "EReg");
		
		this.types = types;
		
	}

	// this is ugly as all hell, but it's late and I'm le tired. TODO: Refactor
	public static function parseClassName(origCN:String):Map<String, String> {
		// Wanted to reuse this as class variable, but it looks like that might cause issues
		// since position etc. is kept on the regex object
		var validClassRegex = ~/[a-zA-Z]/;
		var resolvedName:String;
		var indexOfFirstBracket:Int;
		var baseName:String;
		var listType = false;

		if (origCN.indexOf ("<") > -1) {
			listType = true;
			indexOfFirstBracket = origCN.indexOf ("<");
			resolvedName = origCN.substr (indexOfFirstBracket + 1, origCN.indexOf (">") - indexOfFirstBracket - 1);
			baseName = origCN.substr(0, indexOfFirstBracket + 1);
			baseName += resolvedName.substr(0,(resolvedName.lastIndexOf (".") + 1));
			resolvedName = resolvedName.substr(resolvedName.lastIndexOf (".") + 1);
		} else {
			resolvedName = origCN.substr(origCN.lastIndexOf (".") + 1);
			baseName = origCN.substr(0,(origCN.lastIndexOf (".") + 1));
		}

		var regexMatch = validClassRegex.match(resolvedName);
		var newClassName = "";
		var finalClassNames = new Map<String, String> ();

		finalClassNames.set("original", origCN);
		if (!regexMatch) {
		} else if (validClassRegex.matchedPos().pos > 0) {
			newClassName = resolvedName.substr(validClassRegex.matchedPos().pos) + resolvedName.substr(0,validClassRegex.matchedPos().pos);

			if (baseName.length > 0 && baseName != newClassName) {
				newClassName = (baseName + newClassName);
				if (listType) {
					newClassName += ">";
				}
			}

			finalClassNames.set("updated", newClassName);
		} else {
			finalClassNames.set("updated", origCN);
		}

		return finalClassNames;
	}
	
	private function getClassInfo (data:Dynamic, definition:ClassDefinition):Void {
		definition.className = data.name;

		var parsedClassNames = parseClassName(definition.className);

		if (parsedClassNames["original"] != parsedClassNames["updated"]) {
			definition.originalClassName = parsedClassNames["original"];
			data.name = definition.className = parsedClassNames["updated"];
		}
			 
		definition.parentClassName = Reflect.field (data, "extends");
	}
	
	
	private function getClassMembers (data:Dynamic, definition:ClassDefinition):Void {
		
		if (data.singleton) {
			
			processMethods (cast (data.members.method, Array<Dynamic>), definition.staticMethods);
			processProperties (cast (data.members.property, Array<Dynamic>), definition.staticProperties);
			
		} else {
			
			processMethods (cast (data.members.method, Array<Dynamic>), definition.methods);
			processProperties (cast (data.members.property, Array<Dynamic>), definition.properties);
			processMethods (cast (data.statics.method, Array<Dynamic>), definition.staticMethods);
			processProperties (cast (data.members.property, Array<Dynamic>), definition.staticProperties);
			
			if (Reflect.hasField (data.members, "cfg")) {
				
				var configProperties = cast (data.members.cfg, Array<Dynamic>);
				
				if (configProperties.length > 0 || cast (data.subclasses, Array<Dynamic>).length > 0) {
					
					var configDefinition = new ClassDefinition ();
					configDefinition.isConfigClass = true;
					configDefinition.className = definition.className + "Config";
					
					if (definition.parentClassName != null && definition.parentClassName != "") {
						
						configDefinition.parentClassName = definition.parentClassName + "Config";
						
					}
					
					processProperties (cast (data.members.cfg, Array<Dynamic>), configDefinition.properties);
					definitions.set (configDefinition.className, configDefinition);
					
				}
				
			}
			
		}
		
	}
	
	
	private function processFile (file:String, basePath:String):Void {
		
		BuildHX.print ("Processing " + file);
		
		var content = BuildHX.getFileContent (basePath + file);
		var data = BuildHX.parseJSON (content);
		
		var definition = definitions.get (data.name);
		
		if (definition == null) {
			
			definition = new ClassDefinition ();
			
		}
		
		getClassInfo (data, definition);
		getClassMembers (data, definition);
		
		definitions.set (definition.className, definition);
		
	}
	
	
	public override function processFiles (files:Array<String>, basePath:String):Void {
		
		for (file in files) {
			
			var process = true;
			
			for (ignoredFile in ignoredFiles) {
				
				if (file == ignoredFile) {
					
					process = false;
					
				}
				
			}
			
			if (process) {
				
				processFile (file, basePath);
				
			}
			
		}
		
	}
	
	
	private function processMethods (methodsData:Array<Dynamic>, methods:Map <String, ClassMethod>):Void {
		
		for (methodData in methodsData) {
			
			if (methodData.name == "constructor" || methodData.deprecated == null) {
				
				var method = new ClassMethod ();
				
				if (methodData.name == "constructor") {
					
					method.name = "new";
					method.returnType = "Void";
					
				} else {
					
					method.name = methodData.name;
					if (Reflect.field (methodData, "return").type != null) {
						var parsedTypeName = parseClassName(Reflect.field (methodData, "return").type);
						method.returnType = parsedTypeName["updated"];
					} else {
						method.returnType = null;
					}
					
				}
				
				method.owner = methodData.owner;
				
				for (param in cast (methodData.params, Array<Dynamic>)) {
					
					switch (param.name) {
						case "default":
							param.name = "_default";
					}
					method.parameterNames.push (param.name);
					method.parameterOptional.push (param.optional);
					var parsedTypeName = parseClassName(param.type);
					method.parameterTypes.push (parsedTypeName["updated"]);
					
				}
				
				if (!methods.exists (method.name)) {
					
					methods.set (method.name, method);
					
				}
				
			}
			
		}
		
	}
	
	
	private function processProperties (propertiesData:Array<Dynamic>, properties:Map <String, ClassProperty>):Void {
		
		for (propertyData in propertiesData) {
			
			if (propertyData.deprecated == null) {
				
				var property = new ClassProperty ();
				property.name = propertyData.name;
				property.owner = propertyData.owner;
				var parsedTypeName = parseClassName(propertyData.type);
				property.type = parsedTypeName["updated"];

				if (!properties.exists (property.name)) {
					
					properties.set (property.name, property);
					
				}
				
			}
			
		}
		
	}
	
	
	private override function resolveClass (definition:ClassDefinition):Void {
		
		BuildHX.addImport (resolveImport (definition.parentClassName), definition);
		
		for (method in definition.methods) {
			
			if (method.owner == definition.className || method.owner.indexOf ("mixin") > -1) {
				
				BuildHX.addImport (resolveImport (method.returnType), definition);
				
				for (paramType in method.parameterTypes) {
					
					BuildHX.addImport (resolveImport (paramType), definition);
					
				}
				
			} else {
				
				method.ignore = true;
				
			}
			
		}
		
		for (property in definition.properties) {
			
			if (property.owner == definition.className || (definition.isConfigClass && property.owner == definition.className.substr (0, definition.className.length - "Config".length)) || property.owner.indexOf ("mixin") > -1) {
				
				BuildHX.addImport (resolveImport (property.type), definition);
				
			} else {
				
				property.ignore = true;
				
			}
			
		}
		
		for (method in definition.staticMethods) {
			
			if (method.owner == definition.className || method.owner.indexOf ("mixin") > -1) {
				
				BuildHX.addImport (resolveImport (method.returnType), definition);
				
				for (paramType in method.parameterTypes) {
					
					BuildHX.addImport (resolveImport (paramType), definition);
					
				}
				
			} else {
				
				method.ignore = true;
				
			}
			
		}
		
		for (property in definition.staticProperties) {
			
			if (property.owner == definition.className || property.owner.indexOf ("mixin") > -1) {
				
				BuildHX.addImport (resolveImport (property.type), definition);
				
			} else {
				
				property.ignore = true;
				
			}
			
		}
		
	}
	
	public override function resolveImport (type:String):Array<String> {

		var type = resolveType (type, false);

		if (type.indexOf ("<") > -1) {

			var indexOfFirstBracket = type.indexOf ("<");
			type = type.substr (indexOfFirstBracket + 1, type.indexOf (">") - indexOfFirstBracket - 1);
		}

		if (type == "HtmlDom") {

			type = "js.html.Element";

		}

		if (type.indexOf (".") == -1) {

			return [];

		} else {

			return [type];

		}

	}
	
	
	public override function resolveType (type:String, abbreviate:Bool = true):String {
		
		if (type == null) {
			
			return "Void";
			
		}
		
		var isList = false;
		var listType = "";
		
		if (type.substr (-2) == "[]") {
			isList = true;
			listType = "Array";
			type = type.substr (0, type.length - 2);
			
		}

		if (type.indexOf ("<") > -1) {
			isList = true;
			var indexOfFirstBracket = type.indexOf ("<");
			listType = type.substr(0, indexOfFirstBracket);
			type = type.substr (indexOfFirstBracket + 1, type.indexOf (">") - indexOfFirstBracket - 1);
		}
		
		var resolvedType:String = "";
		
		if (type.indexOf ("/") > -1) {
			
			resolvedType = "Dynamic";
			
		} else if (types.exists (type)) {
			
			resolvedType = types.get (type);
			
		} else {
			
			if (abbreviate) {
				
				resolvedType = BuildHX.resolveClassName (type);
				
			} else {
				
				resolvedType = BuildHX.resolvePackageNameDot (type) + BuildHX.resolveClassName (type);
				
			}
			
		}
		if (isList) {
			return '${listType}<${resolvedType}>';
			
		} else {
			
			return resolvedType;
			
		}
		
	}
	
	
}
