////////////////////////////////////////////////////////////////////////////////
//
//  Licensed to the Apache Software Foundation (ASF) under one or more
//  contributor license agreements.  See the NOTICE file distributed with
//  this work for additional information regarding copyright ownership.
//  The ASF licenses this file to You under the Apache License, Version 2.0
//  (the "License"); you may not use this file except in compliance with
//  the License.  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
////////////////////////////////////////////////////////////////////////////////
package org.apache.flex.ant.tags
{
    import flash.events.Event;
    
    import mx.core.IFlexModuleFactory;
    
    import org.apache.flex.ant.Ant;
    import org.apache.flex.ant.tags.supportClasses.TaskHandler;
    
    [Mixin]
    public class Target extends TaskHandler
    {
        public static function init(mf:IFlexModuleFactory):void
        {
            Ant.antTagProcessors["target"] = Target;
        }
        
        public function Target()
        {
        }
                
        private var project:Project;
		private var ifProperty:String;
		private var unlessProperty:String;
		
        private var _depends:String;
        
        public function get depends():String
        {
            return _depends;
        }
                
        override protected function processAttribute(name:String, value:String):void
        {
            if (name == "depends")
                _depends = value;
			else if (name == "if")
				ifProperty = value;
			else if (name == "unless")
				unlessProperty = value;
            else
                super.processAttribute(name, value);
        }
        
        private var dependsList:Array;
        
        private function processDepends():Boolean
        {
            if (dependsList.length == 0)
            {
                continueOnToSteps();
                return true;
            }

            while (dependsList.length > 0)
            {
                var depend:String = dependsList.shift();
                var t:Target = project.getTarget(depend);
                if (!t.execute(callbackMode, context))
                {
                    t.addEventListener(Event.COMPLETE, dependCompleteHandler);
                    return false;
                }
            }
            
            return continueOnToSteps();
        }
        
        private function dependCompleteHandler(event:Event):void
        {
            processDepends();
        }
        
        private var inExecute:Boolean;
        
        override public function execute(callbackMode:Boolean, context:Object):Boolean
        {
			super.execute(callbackMode, context);
			
            inExecute = true;
            this.callbackMode = callbackMode;
            if (_depends)
            {
                dependsList = _depends.split(",");
                if (!processDepends())
                {
                    inExecute = false;
                    return false;
                }
            }
            
            var ok:Boolean = continueOnToSteps();
            inExecute = false;
            return ok;
        }
        
        private function continueOnToSteps():Boolean
        {
            if (!ant.project.status)
                return true;
            return processSteps();
        }
        
        private var current:int = 0;
        
        private function processSteps():Boolean
        {
			if (ifProperty != null)
			{
				if (!context.hasOwnProperty(ifProperty))
				{
					dispatchEvent(new Event(Event.COMPLETE));
					return true;
				}
			}
			
			if (unlessProperty != null)
			{
				if (context.hasOwnProperty(unlessProperty))
				{
					dispatchEvent(new Event(Event.COMPLETE));
					return true;
				}
			}
			
            if (current == numChildren)
            {
                dispatchEvent(new Event(Event.COMPLETE));
                return true;
            }
            
            while (current < numChildren)
            {
                var step:TaskHandler = getChildAt(current++) as TaskHandler;
                if (!step.execute(callbackMode, context))
                {
                    step.addEventListener(Event.COMPLETE, completeHandler);
                    return false;
                }
                if (!ant.project.status)
                {
                    if (!inExecute)
                        dispatchEvent(new Event(Event.COMPLETE));
                    return true;
                }
                if (callbackMode)
                {
                    ant.functionToCall = processSteps;
                    return false;
                }
            }
            dispatchEvent(new Event(Event.COMPLETE));
            return true;
        }

        private function completeHandler(event:Event):void
        {
            if (!ant.project.status)
            {
                dispatchEvent(new Event(Event.COMPLETE));
                return;                
            }
            if (callbackMode)
                ant.functionToCall = processSteps;
            else
                processSteps();
        }
    }
}