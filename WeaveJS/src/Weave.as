/*
	This Source Code Form is subject to the terms of the
	Mozilla Public License, v. 2.0. If a copy of the MPL
	was not distributed with this file, You can obtain
	one at https://mozilla.org/MPL/2.0/.
*/
package
{
	import weavejs.WeaveAPI;
	import weavejs.api.core.ICallbackCollection;
	import weavejs.api.core.ILinkableHashMap;
	import weavejs.api.core.ILinkableObject;
	import weavejs.api.core.IProgressIndicator;
	import weavejs.api.core.IScheduler;
	import weavejs.api.core.ISessionManager;
	import weavejs.api.data.IAttributeColumn;
	import weavejs.api.data.IAttributeColumnCache;
	import weavejs.api.data.IQualifiedKey;
	import weavejs.api.data.IQualifiedKeyManager;
	import weavejs.core.LinkableBoolean;
	import weavejs.core.LinkableCallbackScript;
	import weavejs.core.LinkableDynamicObject;
	import weavejs.core.LinkableFunction;
	import weavejs.core.LinkableHashMap;
	import weavejs.core.LinkableNumber;
	import weavejs.core.LinkableString;
	import weavejs.core.LinkableSynchronizer;
	import weavejs.core.LinkableVariable;
	import weavejs.core.LinkableWatcher;
	import weavejs.core.ProgressIndicator;
	import weavejs.core.Scheduler;
	import weavejs.core.SessionManager;
	import weavejs.core.SessionStateLog;
	import weavejs.data.AttributeColumnCache;
	import weavejs.data.keys.QKeyManager;
	import weavejs.data.sources.CSVDataSource;
	import weavejs.path.WeavePath;
	import weavejs.path.WeavePathData;
	import weavejs.utils.Dictionary2D;
	import weavejs.utils.JS;
	import weavejs.utils.StandardLib;
	
	public class Weave
	{
		private static const dependencies:Array = [
			LinkableNumber,LinkableString,LinkableBoolean,LinkableVariable,
			LinkableHashMap,LinkableDynamicObject,LinkableWatcher,
			LinkableCallbackScript,LinkableSynchronizer,LinkableFunction,
			null
		];
		
		private static const HISTORY_SYNC_DELAY:int = 100;
		
		public var date:Date = new Date();
		
		public function testme():void
		{
			JS.log(date);
		}
		
		public function Weave()
		{
			WeaveAPI.ClassRegistry.registerSingletonImplementation(IAttributeColumnCache, AttributeColumnCache);
			WeaveAPI.ClassRegistry.registerSingletonImplementation(ISessionManager, SessionManager);
			WeaveAPI.ClassRegistry.registerSingletonImplementation(IQualifiedKeyManager, QKeyManager);
			WeaveAPI.ClassRegistry.registerSingletonImplementation(IScheduler, Scheduler);
			WeaveAPI.ClassRegistry.registerSingletonImplementation(IProgressIndicator, ProgressIndicator);
			
			// set this property for backwards compatibility
			this['WeavePath'] = WeavePath;
			
			root = new LinkableHashMap();
			history = new SessionStateLog(root, HISTORY_SYNC_DELAY);
		}
		
		public function test():void
		{
			SessionStateLog.debug = true;
			
			var lv:LinkableString = root.requestObject('ls', LinkableString, false);
			lv.addImmediateCallback(this, function():void { JS.log('immediate', lv.state); }, true);
			lv.addGroupedCallback(this, function():void { JS.log('grouped', lv.state); }, true);
			lv.state = 'hello';
			lv.state = 'hello';
			path('ls').state('hi').addCallback(null, function():void { JS.log(this+'', this.getState()); });
			lv.state = 'world';
			path('script')
				.request('LinkableCallbackScript')
				.state('script', 'console.log(Weave.className(this), this.get("ldo").target.value, Weave.getState(this));')
				.push('variables', 'ldo')
					.request('LinkableDynamicObject')
					.state(['ls']);
			lv.state = '2';
			lv.state = 2;
			lv.state = '3';
			path('ls2').request('LinkableString');
			path('sync')
				.request('LinkableSynchronizer')
				.state('primaryPath', ['ls'])
				.state('primaryTransform', 'state + "_transformed"')
				.state('secondaryPath', ['ls2'])
				.call(function():void { JS.log(this.weave.path('ls2').getState()) });
			path('csv').request(CSVDataSource)
				.state('csvData', [['a', 'b'], [1, "one"], [2, "two"]])
				.addCallback(null, function():void {
					var csv:CSVDataSource = this.getObject() as CSVDataSource;
					var ids:Array = csv.getColumnIds();
					for each (var id:* in ids)
					{
						var col:IAttributeColumn = csv.getColumnById(id);
						col.addGroupedCallback(null, function(id:*, col:IAttributeColumn):void {
							for each (var key:IQualifiedKey in col.keys)
								JS.log(id, key, col.getValueFromKey(key), col.getValueFromKey(key, Number), col.getValueFromKey(key, String));
						}.bind(this, id, col), true);
					}
				});
		}
		
		/**
		 * The root object in the session state
		 */
		public var root:ILinkableHashMap;
		
		/**
		 * The session history
		 */
		public var history:SessionStateLog;
		
		/**
		 * Creates a WeavePath object.  WeavePath objects are immutable after they are created.
		 * This is a shortcut for "new WeavePath(weave, basePath)".
		 * @param basePath An optional Array (or multiple parameters) specifying the path to an object in the session state.
		 *                 A child index number may be used in place of a name in the path when its parent object is a LinkableHashMap.
		 * @return A WeavePath object.
		 * @see WeavePath
		 */
		public function path(...basePath):WeavePath
		{
			if (basePath.length == 1 && basePath[0] is Array)
				basePath = basePath[0];
			// handle path(linkableObject)
			if (basePath.length == 1 && isLinkable(basePath[0]))
				basePath = getPath(basePath[0]);
			return new WeavePathData(this, basePath);
		}
		
		/**
		 * A shortcut for WeaveAPI.SessionManager.getObject(weave.root, path).
		 * @see weave.api.core.ISessionManager#getObject()
		 */
		public function getObject(path:Array):ILinkableObject
		{
			return WeaveAPI.SessionManager.getObject(root, path);
		}
		
		/**
		 * A shortcut for WeaveAPI.SessionManager.getPath(weave.root, object).
		 * @see weave.api.core.ISessionManager#getPath()
		 */
		public function getPath(object:ILinkableObject):Array
		{
			return WeaveAPI.SessionManager.getPath(root, object);
		}

		
		
		
		//////////////////////////////////////////////////////////////////////////////////
		// static functions for linkable objects
		//////////////////////////////////////////////////////////////////////////////////
		
		/**
		 * Shortcut for WeaveAPI.SessionManager.getPath()
		 * @copy weave.api.core.ISessionManager#getPath()
		 */
		public static function findPath(root:ILinkableObject, descendant:ILinkableObject):Array
		{
			return WeaveAPI.SessionManager.getPath(root, descendant);
		}
		
		/**
		 * Shortcut for WeaveAPI.SessionManager.getObject()
		 * @copy weave.api.core.ISessionManager#getObject()
		 */
		public static function followPath(root:ILinkableObject, path:Array):ILinkableObject
		{
			return WeaveAPI.SessionManager.getObject(root, path);
		}
		
		/**
		 * Shortcut for WeaveAPI.SessionManager.getCallbackCollection()
		 * @copy weave.api.core.ISessionManager#getCallbackCollection()
		 */
		public static function getCallbacks(linkableObject:ILinkableObject):ICallbackCollection
		{
			return WeaveAPI.SessionManager.getCallbackCollection(linkableObject);
		}

		/**
		 * This function is used to detect if callbacks of a linkable object were triggered since the last time this function
		 * was called with the same parameters, likely by the observer.  Note that once this function returns true, subsequent calls will
		 * return false until the callbacks are triggered again.  It's a good idea to specify a private object or function as the observer
		 * so no other code can call detectChange with the same observer and linkableObject parameters.
		 * @param observer The object that is observing the change.
		 * @param linkableObject The object that is being observed.
		 * @param moreLinkableObjects More objects that are being observed.
		 * @return A value of true if the callbacks for any of the objects have triggered since the last time this function was called
		 *         with the same observer for any of the specified linkable objects.
		 */
		public static function detectChange(observer:Object, linkableObject:ILinkableObject, ...moreLinkableObjects):Boolean
		{
			var changeDetected:Boolean = false;
			moreLinkableObjects.unshift(linkableObject);
			// it's important not to short-circuit like a boolean OR (||) because we need to clear the 'changed' flag on each object.
			for each (linkableObject in moreLinkableObjects)
			if (linkableObject && _internalDetectChange(observer, linkableObject, true)) // clear 'changed' flag
				changeDetected = true;
			return changeDetected;
		}
		/**
		 * This function is used to detect if callbacks of a linkable object were triggered since the last time detectChange
		 * was called with the same parameters, likely by the observer.  Note that once this function returns true, subsequent calls will
		 * return false until the callbacks are triggered again, unless clearChangedNow is set to false.  It may be a good idea to specify
		 * a private object as the observer so no other code can call detectChange with the same observer and linkableObject
		 * parameters.
		 * @param observer The object that is observing the change.
		 * @param linkableObject The object that is being observed.
		 * @param clearChangedNow If this is true, the trigger counter will be reset to the current value now so that this function will
		 *        return false if called again with the same parameters before the next time the linkable object triggers its callbacks.
		 * @return A value of true if the callbacks for the linkableObject have triggered since the last time this function was called
		 *         with the same observer and linkableObject parameters.
		 */
		public static function _internalDetectChange(observer:Object, linkableObject:ILinkableObject, clearChangedNow:Boolean = true):Boolean
		{
			var previousCount:* = d2d_linkableObject_observer_triggerCounter.get(linkableObject, observer); // untyped to handle undefined value
			var newCount:uint = WeaveAPI.SessionManager.getCallbackCollection(linkableObject).triggerCounter;
			if (previousCount !== newCount) // !== avoids casting to handle the case (0 !== undefined)
			{
				if (clearChangedNow)
					d2d_linkableObject_observer_triggerCounter.set(linkableObject, observer, newCount);
				return true;
			}
			return false;
		}
		/**
		 * This is a two-dimensional dictionary, where _triggerCounterMap[linkableObject][observer]
		 * equals the previous triggerCounter value from linkableObject observed by the observer.
		 */
		private static const d2d_linkableObject_observer_triggerCounter:Dictionary2D = new Dictionary2D(true, true);
		
		/**
		 * Finds the root ILinkableHashMap for a given ILinkableObject.
		 * @param object An ILinkableObject.
		 * @return The root ILinkableHashMap.
		 */
		public static function getRoot(object:ILinkableObject):ILinkableHashMap
		{
			var sm:ISessionManager = WeaveAPI.SessionManager;
			while (true)
			{
				var owner:ILinkableObject = sm.getLinkableOwner(object);
				if (!owner)
					break;
				object = owner;
			}
			return object as ILinkableHashMap;
		}
		
		/**
		 * Finds the closest ancestor of a descendant given the ancestor type.
		 * @param descendant An object with ancestors.
		 * @param ancestorType The Class definition used to determine which ancestor to return.
		 * @return The closest ancestor of the given type.
		 * @see weave.api.core.ISessionManager#getLinkableOwner()
		 */
		public static function getAncestor(descendant:ILinkableObject, ancestorType:Class):ILinkableObject
		{
			var sm:ISessionManager = WeaveAPI.SessionManager;
			do {
				descendant = sm.getLinkableOwner(descendant);
			} while (descendant && !(descendant is ancestorType));
			
			return descendant;
		}
		
		/**
		 * Shortcut for WeaveAPI.SessionManager.getLinkableOwner()
		 * @copy weave.api.core.ISessionManager#getLinkableOwner()
		 */
		public static function getOwner(child:ILinkableObject):ILinkableObject
		{
			return WeaveAPI.SessionManager.getLinkableOwner(child);
		}
		
		/**
		 * Shortcut for WeaveAPI.SessionManager.getLinkableDescendants()
		 * @copy weave.api.core.ISessionManager#getLinkableDescendants()
		 */
		public static function getDescendants(object:ILinkableObject, filter:Class = null):Array
		{
			return WeaveAPI.SessionManager.getLinkableDescendants(object, filter);
		}
		
		/**
		 * Shortcut for WeaveAPI.SessionManager.getSessionState()
		 * @copy weave.api.core.ISessionManager#getSessionState()
		 */
		public static function getState(linkableObject:ILinkableObject):Object
		{
			return WeaveAPI.SessionManager.getSessionState(linkableObject);
		}
		
		/**
		 * Shortcut for WeaveAPI.SessionManager.setSessionState()
		 * @copy weave.api.core.ISessionManager#setSessionState()
		 */
		public static function setState(linkableObject:ILinkableObject, newState:Object, removeMissingDynamicObjects:Boolean = true):void
		{
			WeaveAPI.SessionManager.setSessionState(linkableObject, newState, removeMissingDynamicObjects);
		}
		
		/**
		 * Shortcut for WeaveAPI.SessionManager.copySessionState()
		 * @copy weave.api.core.ISessionManager#copySessionState()
		 */
		public static function copyState(source:ILinkableObject, destination:ILinkableObject):void
		{
			WeaveAPI.SessionManager.copySessionState(source, destination);
		}
		
		/**
		 * Shortcut for WeaveAPI.SessionManager.linkSessionState()
		 * @copy weave.api.core.ISessionManager#linkSessionState()
		 */
		public static function linkState(primary:ILinkableObject, secondary:ILinkableObject):void
		{
			WeaveAPI.SessionManager.linkSessionState(primary, secondary);
		}
		
		/**
		 * Shortcut for WeaveAPI.SessionManager.unlinkSessionState()
		 * @copy weave.api.core.ISessionManager#unlinkSessionState()
		 */
		public static function unlinkState(first:ILinkableObject, second:ILinkableObject):void
		{
			WeaveAPI.SessionManager.unlinkSessionState(first, second);
		}
		
		/**
		 * Shortcut for WeaveAPI.SessionManager.computeDiff()
		 * @copy weave.api.core.ISessionManager#computeDiff()
		 */
		public static function computeDiff(oldState:Object, newState:Object):Object
		{
			return WeaveAPI.SessionManager.computeDiff(oldState, newState);
		}
		
		/**
		 * Shortcut for WeaveAPI.SessionManager.combineDiff()
		 * @copy weave.api.core.ISessionManager#combineDiff()
		 */
		public static function combineDiff(baseDiff:Object, diffToAdd:Object):Object
		{
			return WeaveAPI.SessionManager.combineDiff(baseDiff, diffToAdd);
		}
		
		/**
		 * Shortcut for WeaveAPI.SessionManager.newDisposableChild() and WeaveAPI.SessionManager.registerDisposableChild()
		 * @see weave.api.core.ISessionManager#newDisposableChild()
		 * @see weave.api.core.ISessionManager#registerDisposableChild()
		 */
		public static function disposableChild(disposableParent:Object, disposableChildOrType:Object):*
		{
			if (JS.isClass(disposableChildOrType))
				return WeaveAPI.SessionManager.newDisposableChild(disposableParent, JS.asClass(disposableChildOrType));
			return WeaveAPI.SessionManager.registerDisposableChild(disposableParent, disposableChildOrType);
		}
		
		/**
		 * Shortcut for WeaveAPI.SessionManager.newLinkableChild() and WeaveAPI.SessionManager.registerLinkableChild()
		 * @see weave.api.core.ISessionManager#newLinkableChild()
		 * @see weave.api.core.ISessionManager#registerLinkableChild()
		 */
		public static function linkableChild(linkableParent:Object, linkableChildOrType:Object, callback:Function = null, useGroupedCallback:Boolean = false):*
		{
			if (JS.isClass(linkableChildOrType))
				return WeaveAPI.SessionManager.newLinkableChild(linkableParent, JS.asClass(linkableChildOrType), callback, useGroupedCallback);
			return WeaveAPI.SessionManager.registerLinkableChild(linkableParent, linkableChildOrType as ILinkableObject, callback, useGroupedCallback);
		}
		
		/**
		 * Shortcut for WeaveAPI.SessionManager.disposeObject()
		 * @copy weave.api.core.ISessionManager#disposeObject()
		 */
		public static function dispose(object:Object):void
		{
			WeaveAPI.SessionManager.disposeObject(object);
		}
		
		/**
		 * Shortcut for WeaveAPI.SessionManager.objectWasDisposed()
		 * @copy weave.api.core.ISessionManager#objectWasDisposed()
		 */
		public static function wasDisposed(object:Object):Boolean
		{
			return WeaveAPI.SessionManager.objectWasDisposed(object);
		}
		
		/**
		 * Shortcut for WeaveAPI.SessionManager.linkableObjectIsBusy()
		 * @copy weave.api.core.ISessionManager#linkableObjectIsBusy()
		 */
		public static function isBusy(object:ILinkableObject):Boolean
		{
			return WeaveAPI.SessionManager.linkableObjectIsBusy(object);
		}
		
		/**
		 * Checks if an object or class implements ILinkableObject
		 */
		public static function isLinkable(objectOrClass:Object):Boolean
		{
			if (objectOrClass is ILinkableObject)
				return true;
			// test class definition
			return objectOrClass && objectOrClass.prototype is ILinkableObject;
		}
		
		public static function callLater(context:Object, func:Function, args:Array = null):void
		{
			// temporary solution?
			JS.setTimeout(function():void {
				if (!wasDisposed(context))
					func.apply(context, args);
			}, 0);
		}
		
		
		
		//////////////////////////////////////////////////////////////////////////////////
		// static general helper functions
		//////////////////////////////////////////////////////////////////////////////////
		
		/**
		 * Gets the qualified class name from a class definition or an object instance.
		 */
		public static function className(def:Object):String
		{
			if (!def)
				return null;
			
			if (!def.prototype)
				def = def.constructor;
			
			if (def.prototype && def.prototype.FLEXJS_CLASS_INFO)
				return def.prototype.FLEXJS_CLASS_INFO.names[0].qName;
			
			return def.name;
		}
		
		public static const defaultPackages:Array = [
			'weavejs.core'
		];
		
		public static function getDefinition(name:String):*
		{
			var def:* = JS.global;
			var names:Array = name.split('.');
			for each (var key:String in names)
			{
				if (def !== undefined)
					def = def[key];
				else
					break;
			}
			
			if (!def && names.length == 1)
			{
				for each (var pkg:String in defaultPackages)
				{
					def = getDefinition(pkg + '.' + name);
					if (def)
						return def;
				}
			}
			
			return def;
		}
		
		/**
		 * Generates a deterministic JSON-like representation of an object, meaning object keys appear in sorted order.
		 * @param value The object to stringify.
		 * @param replacer A function like function(key:String, value:*):*
		 * @param indent Either a Number or a String to specify indentation of nested values
		 * @param json_values_only If this is set to true, only JSON-compatible values will be used (NaN/Infinity/undefined -> null)
		 */
		public static function stringify(value:*, replacer:Function = null, indent:* = null, json_values_only:Boolean = false):String
		{
			indent = typeof indent === 'number' ? StandardLib.lpad('', indent, ' ') : indent as String || ''
			return _stringify("", value, replacer, indent ? '\n' : '', indent, json_values_only);
		}
		private static function _stringify(key:String, value:*, replacer:Function, lineBreak:String, indent:String, json_values_only:Boolean):String
		{
			if (replacer != null)
				value = replacer(key, value);
			
			var output:Array;
			var item:*;
			
			if (typeof value === 'string')
				return encodeString(value);
			
			// non-string primitives
			if (value == null || typeof value != 'object')
			{
				if (json_values_only && (value === undefined || !isFinite(value as Number)))
					value = null;
				return String(value) || String(null);
			}
			
			// loop over keys in Array or Object
			var lineBreakIndent:String = lineBreak + indent;
			var valueIsArray:Boolean = value is Array;
			output = [];
			if (valueIsArray)
			{
				for (var i:int = 0; i < value.length; i++)
					output.push(_stringify(String(i), value[i], replacer, lineBreakIndent, indent, json_values_only));
			}
			else if (typeof value == 'object')
			{
				for (key in value)
					output.push(encodeString(key) + ": " + _stringify(key, value[key], replacer, lineBreakIndent, indent, json_values_only));
				// sort keys
				output.sort();
			}
			
			if (output.length == 0)
				return valueIsArray ? "[]" : "{}";
			
			var lb:String = valueIsArray ? "[" : "{";
			var rb:String = valueIsArray ? "]" : "}";
			return lb
				+ lineBreakIndent
				+ output.join(indent ? ',' + lineBreakIndent : ', ')
				+ lineBreak
				+ rb;
		}
		/**
		 * This function surrounds a String with quotes and escapes special characters using ActionScript string literal format.
		 * @param string A String that may contain special characters.
		 * @param quote Set this to either a double-quote or a single-quote.
		 * @return The given String formatted for ActionScript.
		 */
		private static function encodeString(string:String, quote:String = '"'):String
		{
			if (string == null)
				return 'null';
			var result:Array = new Array(string.length);
			for (var i:int = 0; i < string.length; i++)
			{
				var chr:String = string.charAt(i);
				var esc:String = chr == quote ? quote : ENCODE_LOOKUP[chr];
				result[i] = esc ? '\\' + esc : chr;
			}
			return quote + result.join('') + quote;
		}
		private static const ENCODE_LOOKUP:Object = {'\b':'b', '\f':'f', '\n':'n', '\r':'r', '\t':'t', '\\':'\\'};
		
		/**
		 * This is a convenient global function for retrieving localized text.
		 * Sample syntax:
		 *     Weave.lang("hello world")
		 * 
		 * You can also specify a format string with parameters which will be passed to StandardLib.substitute():
		 *     Weave.lang("{0} and {1}", first, second)
		 * 
		 * @param text The original text or format string to translate.
		 * @param parameters Parameters to be passed to StandardLib.substitute() if the text is to be treated as a format string.
		 */
		public static function lang(text:String, ...parameters):String
		{
			var newText:String = text;
			
			try
			{
				// call localize() either way to let the LocaleManager know that we are interested in translations of this text.
				newText = WeaveAPI.LocaleManager.localize(text);
				
				if (WeaveAPI.LocaleManager.getLocale() == 'developer')
				{
					parameters.unshift(text);
					return 'lang("' + parameters.join('", "') + '")';
				}
			}
			catch (e:Error)
			{
			}
			
			if (parameters.length)
				return StandardLib.substitute(newText, parameters);
			
			return newText;
		}
	}
}