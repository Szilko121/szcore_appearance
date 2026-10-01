local rate={}
local function get(source)
    local p=exports.szcore:GetPlayer(source);if not p then return nil end
    local raw=MySQL.scalar.await('SELECT appearance FROM szcore_appearance WHERE citizenid=?',{p.PlayerData.citizenid});if not raw then return nil end
    local ok,data=pcall(json.decode,raw);return ok and data or nil
end
local function cleanNumber(v,min,max,default)v=tonumber(v);if not v or v~=v then return default end;return math.max(min,math.min(max,v))end
local function sanitize(a)
    if type(a)~='table'then return nil end
    local model=tostring(a.model or'mp_m_freemode_01'):sub(1,64);if not SzCoreAppearanceConfig.allowedModels[model] then model='mp_m_freemode_01' end
    local out={model=model,components={},props={},faceFeatures={},overlays={},headBlend={},hair={}}
    if a.modelHash then out.modelHash=tonumber(a.modelHash)end
    for k,v in pairs(type(a.components)=='table'and a.components or{})do local id=tonumber(k);if id and id>=0 and id<=11 and type(v)=='table'then out.components[tostring(id)]={drawable=math.max(0,math.min(255,math.floor(tonumber(v.drawable)or 0))),texture=math.max(0,math.min(255,math.floor(tonumber(v.texture)or 0))),palette=math.max(0,math.min(3,math.floor(tonumber(v.palette)or 0)))}end end
    for k,v in pairs(type(a.props)=='table'and a.props or{})do local id=tonumber(k);if id and id>=0 and id<=7 and type(v)=='table'then out.props[tostring(id)]={drawable=math.max(-1,math.min(255,math.floor(tonumber(v.drawable)or-1))),texture=math.max(0,math.min(255,math.floor(tonumber(v.texture)or 0)))}end end
    for k,v in pairs(type(a.faceFeatures)=='table'and a.faceFeatures or{})do local id=tonumber(k);if id and id>=0 and id<=19 then out.faceFeatures[tostring(id)]=cleanNumber(v,-1,1,0)end end
    for k,v in pairs(type(a.overlays)=='table'and a.overlays or{})do local id=tonumber(k);if id and id>=0 and id<=12 and type(v)=='table'then out.overlays[tostring(id)]={index=math.max(0,math.floor(tonumber(v.index)or 0)),opacity=cleanNumber(v.opacity,0,1,1),color=math.max(0,math.floor(tonumber(v.color)or 0)),colorType=math.max(0,math.min(2,math.floor(tonumber(v.colorType)or 0)))}end end
    local hb=type(a.headBlend)=='table'and a.headBlend or{};out.headBlend={shapeFirst=math.floor(cleanNumber(hb.shapeFirst,0,45,0)),shapeSecond=math.floor(cleanNumber(hb.shapeSecond,0,45,0)),skinFirst=math.floor(cleanNumber(hb.skinFirst,0,45,0)),skinSecond=math.floor(cleanNumber(hb.skinSecond,0,45,0)),shapeMix=cleanNumber(hb.shapeMix,0,1,.5),skinMix=cleanNumber(hb.skinMix,0,1,.5)}
    local h=type(a.hair)=='table'and a.hair or{};out.hair={color=math.max(0,math.min(63,math.floor(tonumber(h.color)or 0))),highlight=math.max(0,math.min(63,math.floor(tonumber(h.highlight)or 0)))}
    return out
end
local function save(source,data)
    local p=exports.szcore:GetPlayer(source);if not p then return false,'player_not_found'end
    local now=GetGameTimer();if rate[source]and now-rate[source]<1000 then return false,'rate_limited'end;rate[source]=now
    local safe=sanitize(data);if not safe then return false,'invalid_appearance'end
    local encoded=json.encode(safe);if #encoded>120000 then return false,'appearance_too_large'end
    MySQL.prepare.await([[INSERT INTO szcore_appearance(citizenid,appearance) VALUES (?,?) ON DUPLICATE KEY UPDATE appearance=VALUES(appearance)]],{p.PlayerData.citizenid,encoded})
    exports.szcore:Audit('appearance.save',source,p.PlayerData.citizenid,{});return true
end
exports.szcore:CreateCallback('szcore_appearance:get',get);exports.szcore:CreateCallback('szcore_appearance:save',save)
local function outfits(source)
    local p=exports.szcore:GetPlayer(source);if not p then return {} end
    return MySQL.query.await('SELECT id,name,created_at,updated_at FROM szcore_outfits WHERE citizenid=? ORDER BY updated_at DESC',{p.PlayerData.citizenid}) or {}
end
local function saveOutfit(source,name,data)
    local p=exports.szcore:GetPlayer(source);if not p then return false,'player_not_found' end
    name=tostring(name or''):gsub('^%s+',''):gsub('%s+$',''):sub(1,64);if name=='' then return false,'invalid_name' end
    local count=tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM szcore_outfits WHERE citizenid=?',{p.PlayerData.citizenid})) or 0;if count>=SzCoreAppearanceConfig.maxOutfits then return false,'outfit_limit' end
    local safe=sanitize(data);if not safe then return false,'invalid_appearance' end
    MySQL.insert.await('INSERT INTO szcore_outfits(citizenid,name,appearance) VALUES (?,?,?)',{p.PlayerData.citizenid,name,json.encode(safe)});exports.szcore:Audit('appearance.outfit.save',source,p.PlayerData.citizenid,{name=name});return true
end
local function deleteOutfit(source,id)
    local p=exports.szcore:GetPlayer(source);if not p then return false end
    local ok=MySQL.update.await('DELETE FROM szcore_outfits WHERE id=? AND citizenid=?',{tonumber(id),p.PlayerData.citizenid})>0;if ok then exports.szcore:Audit('appearance.outfit.delete',source,p.PlayerData.citizenid,{id=id})end;return ok
end
local function getOutfit(source,id)
    local p=exports.szcore:GetPlayer(source);if not p then return nil end
    local raw=MySQL.scalar.await('SELECT appearance FROM szcore_outfits WHERE id=? AND citizenid=?',{tonumber(id),p.PlayerData.citizenid});if not raw then return nil end;local ok,d=pcall(json.decode,raw);return ok and d or nil
end
exports.szcore:CreateCallback('szcore_appearance:outfits',outfits)
exports.szcore:CreateCallback('szcore_appearance:saveOutfit',saveOutfit)
exports.szcore:CreateCallback('szcore_appearance:deleteOutfit',deleteOutfit)
exports.szcore:CreateCallback('szcore_appearance:getOutfit',getOutfit)
RegisterNetEvent('szcore_appearance:save',function(data)save(source,data)end)
AddEventHandler('playerDropped',function()rate[source]=nil end)
AddEventHandler('szcore:server:playerLoaded',function(source)local data=get(source);if data then TriggerClientEvent('szcore_appearance:apply',source,data)end end)
exports('GetAppearance',get);exports('SaveAppearance',save);exports('GetOutfits',outfits);exports('SaveOutfit',saveOutfit);exports('DeleteOutfit',deleteOutfit)
