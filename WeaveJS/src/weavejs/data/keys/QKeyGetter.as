/* ***** BEGIN LICENSE BLOCK *****
 *
 * This file is part of Weave.
 *
 * The Initial Developer of Weave is the Institute for Visualization
 * and Perception Research at the University of Massachusetts Lowell.
 * Portions created by the Initial Developer are Copyright (C) 2008-2015
 * the Initial Developer. All Rights Reserved.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 * 
 * ***** END LICENSE BLOCK ***** */

package weavejs.data.keys
{
	import weavejs.WeaveAPI;
	import weavejs.utils.JS;
	import weavejs.utils.WeavePromise;

	internal class QKeyGetter extends WeavePromise
	{
		public function QKeyGetter(manager:QKeyManager, relevantContext:Object)
		{
			super(relevantContext);
			
			this.manager = manager;
		}
		
		public function asyncStart(keyType:String, keyStrings:Array, outputKeys:Array = null):QKeyGetter
		{
			if (!keyStrings)
				keyStrings = [];
			this.manager = manager;
			this.keyType = keyType;
			this.keyStrings = keyStrings;
			this.i = 0;
			this.outputKeys = outputKeys || new Array(keyStrings.length);
			
			this.outputKeys.length = keyStrings.length;
			// high priority because all visualizations depend on key sets
			WeaveAPI.Scheduler.startTask(relevantContext, iterate, WeaveAPI.TASK_PRIORITY_HIGH, asyncComplete, Weave.lang("Initializing {0} record identifiers", keyStrings.length));
			
			return this;
		}
		
		private var asyncCallback:Function;
		private var i:int;
		private var manager:QKeyManager;
		private var keyType:String;
		private var keyStrings:Array;
		private var outputKeys:Array;
		private var batch:uint = 5000;
		
		private function iterate(stopTime:int):Number
		{
			for (; i < keyStrings.length; i += batch)
			{
				if (JS.now() > stopTime)
					return i / keyStrings.length;
				
				manager.getQKeys_range(keyType, keyStrings, i, Math.min(i + batch, keyStrings.length), outputKeys);
			}
			return 1;
		}
		
		private function asyncComplete():void
		{
			setResult(this.outputKeys);
		}
	}
}