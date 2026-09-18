-- Pure Lua illustration path resolver, not an UrhoX API wrapper.
local M = {}
local pools={ ["男"]={"portrait_m01","portrait_m02"}, ["女"]={"portrait_f01","portrait_f02"} }
local known={portrait_m01=true,portrait_m02=true,portrait_f01=true,portrait_f02=true}
local function hash(s) local h=5381; for i=1,#s do h=(h*33+s:byte(i))%2147483647 end; return h end
-- Call once at member creation/import and save artId. NEVER call to randomize during rendering.
function M.Assign(member,runId)
 if type(member)~="table" or member.id==nil then return nil,"stable member id required" end
 if member.artId then return known[member.artId] and member.artId or nil,"keep persisted artId; unknown ids require explicit migration" end
 local pool=pools[member.sex];if not pool then return nil,"use neutral UI placeholder; no matching pool" end
 member.artId=pool[hash(tostring(runId)..":"..tostring(member.id))%#pool+1];member.artVersion="1.0.0";return member.artId
end
function M.Stage(age)
 if age<5 then return "infant" elseif age<13 then return "child" elseif age<28 then return "young" elseif age<55 then return "adult" end
 return "elder"
end
-- Stage is ART ONLY, never a marriage/fertility/health rule.
function M.Portrait(member,size,visualStatus)
 if not known[member.artId] then return nil,"unassigned artId" end
 local age=member.alive==false and (member.ageAtDeath or member.age) or member.age
 if type(age)~="number" or age<0 then return nil,"invalid visual age" end
 local stage=member.artStageAtDeath or M.Stage(age)
 local stages={infant=true,child=true,young=true,adult=true,elder=true};if not stages[stage] then return nil,"unknown stage" end
 local state=member.alive==false and "deceased" or (visualStatus=="sick" and "sick" or "normal")
 local b="assets/characters/"..member.artId.."/"..stage
 if size=="detail" then return b.."_detail"..(state=="normal" and "" or "_"..state)..".png" end
 return b.."_"..state.."_256.png"
end
function M.SelectedOverlay() return "assets/ui/portrait_selected.svg" end
function M.House(homeId,state)
 local homes={rented=true,simple=true,courtyard=true,estate=true};local states={normal=true,damaged=true,upgraded=true,relocated=true}
 if not homes[homeId] then return nil,"unknown homeId" end
 return "assets/houses/"..homeId.."_"..(states[state] and state or "normal")..".png"
end
function M.Event(event,relicId)
 local map={medical_find="medical",notes_choice="medical",plan_work="repair",community_request="neighbors",school="school",roof="roof",jade_search="jade",leader="leadership",migration="migration",invite_branch="reunion"}
 local relic={ruler="ruler",book="book",letter="letter",plan="repair",newbook="reunion",jade="jade",notes="medical"}
 local id=map[event.type]
 if event.type=="relic_resolution" then id=relic[relicId] end
 if event.type=="growth" then id=event.jobId=="doctor" and "medical" or (event.jobId=="craft" and "repair" or "school") end
 return id and ("assets/events/"..id..".png") or nil
end
return M
