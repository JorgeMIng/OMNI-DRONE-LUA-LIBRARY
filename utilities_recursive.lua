utilities_recursive = {}

--[[

This is a recursive switch that get cases from the hierarchy tree from child class to base class and would execute 
the function on the switch.


The default case can be setup with defaultFunc with a function or with a case in the cases with the name "default"
In case no default case or default func is setup the function would not execute nothing.
If any default is executed "wasDefault" of the result table is True


* rec_switch_custum (command,getCasesFunc,callerClass,baseClass,

    configsGetCases={protected_cases Default:{}, conservedOld Default:true, defaultFunc:false}
* command: command code to execute
* args: args to use in command
* getCasesFunc: String with the name of the function to call for getting the cases in the specific subclass
* callerClass: in most cases use self it would be the class calling this method which will be use as starting point 
    for the the recursive switch checking superClasses until reaching the baseClass
* baseClass: this class will have implemented a "build" method calling this function and using his class name
    this variable, subclasses of this method will be calling the specific getCasesFunc specified until reaching this class
* configGetCases: table with config params
    - protected_cases: table with cases or function to get those cases.  This cases will be protected in case of same 
        key in the final cases table
    - conservedOld: True: the first cases to be set would not be able to be change considering the order of the recursion
    the child classes would always change the cases, False: the base class would rechange the cases. The default is True

RETURNS
        table {"result": result of the function of the case, "was_default" if deafult was executed}







This means that we can define a switch with custums cases and redifined cases of the base class if needed more easly
        Example: 
            BaseClass:
                function Test:getCases(d)
                    {
                        ["hush"] = function (args) --kill command
                            self:resetRedstone()
                            self.run_firmware = false
                        end,
                        ["restart"] = function (args) --kill command
                            self:resetRedstone()
                            os.reboot()
                        end,
                        default = function ()
                            self.remoteControlManager:protocols(msg)
                            self:customProtocols(msg)
                        end,
                    }
                end 

                function Test:build(d)
                    Rec.rec_switch_custum("hush",args,"getCases",self,Test)
                end 
                ///or//
                function Test:build(d)
                    Rec.rec_switch_custum("hush",args,"getCases",self,Test,{protected_cases={["hey"]=function()end},conservedOld=false,defaultFunc=function()end})
                end
            
            SubClass:
                function Test:getCases(d)
                        {
                            ["hush2"] = function (args) --kill command
                                self:resetRedstone()
                                self.run_firmware = false
                            end,
                            ["restart"] = function (args) --kill command
                                self:resetRedstone()
                                os.reboot()
                            end,
                            default = function ()
                                self.remoteControlManager:protocols(msg)
                                self:customProtocols(msg)
                            end,
                        }
                    end 
            




]]--





function utilities_recursive.rec_switch_custum(command,args,getCasesFunc,callerClass,baseClass,configsGetCases)
    setmetatable(configsGetCases,{__index={protected_cases={},conservedOld=true,defaultFunc=false}})
    command = command and tonumber(command) or command
    local result
    local was_default=false
    local case = utilities_recursive.rec_get_cases_custum(getCasesFunc,callerClass,baseClass,configsGetCases)

    if case[command] then
        result = case[command](args)
    elseif type(configsGetCases.defaultFunc)=="function" or case["default"] then
        was_default=true
        if type(configsGetCases.defaultFunc)=="function" then
            result= configsGetCases.defaultFunc()
        else
            result=case["default"]()
        end
    else
        was_default=true
    end

    return {result=result,was_default=was_default}
end

--[[
This class is used to get recursively cases defining a function to get cases, a caller class and a base class to end
it would go from the caller class using superClass until base case combining the params get in each instance.


* paramsGetCases (command,getCasesFunc,callerClass,baseClass, configsGetCases={protected_cases Default:{}, conservedOld Default:true }
* getCasesFunc String with the name of the function to call for getting the cases in the specific subclass
* callerClass in most cases use self it would be the class calling this method which will be use as starting point 
    for the the recursive switch checking superClasses until reaching the baseClass
* baseClass this class will have implemented a "build" method calling this function and using his class name
    this variable, subclasses of this method will be calling the specific getCasesFunc specified until reaching this class
* configGetCases table with config params
    - protected_cases: table with cases or function to get those cases.  This cases will be protected in case of same 
        key in the final cases table
    - conservedOld: True: the first cases to be set would not be able to be change considering the order of the recursion
    the child classes would always change the cases, False: the base class would rechange the cases. The default is True

RETURNS
        Table with cases

    ***** REDIFINING the build functionw with this class at subclasses would need to be given the base class (require it)
        or the recursion would be cut in that point
This means that we can define a switch with custums cases and redifined cases of the base class if needed more easly
        Example: 
            BaseClass:
                function Test:getCases(d)
                    {
                        ["hush"] = function (args) --kill command
                            self:resetRedstone()
                            self.run_firmware = false
                        end,
                        ["restart"] = function (args) --kill command
                            self:resetRedstone()
                            os.reboot()
                        end,
                        default = function ()
                            self.remoteControlManager:protocols(msg)
                            self:customProtocols(msg)
                        end,
                    }
                end 

                function Test:build(d)
                    Rec.rec_get_cases_custum("getCases",self,Test,{})
                end 

                ///or//
                function Test:build(d)
                    Rec.rec_switch_custum("getCases",self,Test,{protected_cases={["hey"]=function()end},conservedOld=false})
                end
            
            SubClass:
                function Test:getCases(d)
                        {
                            ["hush2"] = function (args) --kill command
                                self:resetRedstone()
                                self.run_firmware = false
                            end,
                            ["restart"] = function (args) --kill command
                                self:resetRedstone()
                                os.reboot()
                            end,
                            default = function ()
                                self.remoteControlManager:protocols(msg)
                                self:customProtocols(msg)
                            end,
                        }
                    end 
            




]]--
function utilities_recursive.rec_get_cases_custum(getCasesFunc,callerClass,baseClass,configsGetCases)
    setmetatable(configsGetCases,{__index={protected_cases={},conservedOld=true}})
    
    local class=callerClass
    local params_global={}
    local protected_cases={}
    if type(configsGetCases.protected_cases)=="function" then
        protected_cases= configsGetCases:protected_cases()
    elseif type(configsGetCases.protected_cases)=="table" then
        protected_cases= configsGetCases.protected_cases
    end

        
    while(baseClass~=class) do
        local params = class[getCasesFunc]()
        

        class = class.superClass
        params_global = utilities_recursive.combined_params(params,params_global,configsGetCases.conservedOld)

        
       

    end

    local paramsBase = baseClass[getCasesFunc]()
    params_global = utilities_recursive.combined_params(paramsBase,params_global,configsGetCases.conservedOld)

    

    -- setup protected params
    
    params_global = utilities_recursive.combined_params(configsGetCases.protected_cases,params_global,false)
    
    return params_global
end



-- params (new_params,old_params,conserverOld)
function utilities_recursive.combined_params(new_params,old_params,conservedOld)
    
    
    local combined_params_v=old_params
    for key,value in pairs(new_params) do
        -- if conserveOld is False old all keys are added/changed 
        -- if conserveOld is True only new keys are added
        if (not conservedOld) or (not old_params[key]) then
            combined_params_v[key]=value
        end
    end
    return combined_params_v
    
end




return utilities_recursive