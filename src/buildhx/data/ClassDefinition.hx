package buildhx.data;

/**
 * ...
 * @author Joshua Granick
 */

class ClassDefinition {
	
	
	public var className:String;
	public var comment:String;
	public var ignore:Bool;
	public var imports:Map <String, String>;
	public var interfaces:Map <String, String>;
	public var isConfigClass:Bool;
	// abusing this structure for type definitions
	// make its own class later on
	public var isTypeDef:Bool;
	public var typeParams:String;
	public var returnType:String;
	public var isGeneric:Bool;
	// end typedef abuse
	public var methods:Map <String, ClassMethod>;
	public var nativeClassName:String;
	public var nativeHeader:String;
	public var parentClassName:String;
	public var properties:Map <String, ClassProperty>;
	public var staticMethods:Map <String, ClassMethod>;
	public var staticProperties:Map <String, ClassProperty>;
	public var type:String;
	
	public function new () {
		
		imports = new Map <String, String> ();
		interfaces = new Map <String, String> ();
		methods = new Map <String, ClassMethod> ();
		properties = new Map <String, ClassProperty> ();
		staticMethods = new Map <String, ClassMethod> ();
		staticProperties = new Map <String, ClassProperty> ();
		comment = "";
	}
	
	
}
