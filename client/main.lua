local creator=false;local current=nil;local original=nil;local cam=nil;local outfits={}
local componentNames={['0']='Face',['1']='Mask',['2']='Hair',['3']='Torso',['4']='Pants',['5']='Bag',['6']='Shoes',['7']='Accessory',['8']='Undershirt',['9']='Armor',['10']='Decal',['11']='Top'}
local overlayNames={['0']='Bőrhibák',['1']='Szakáll',['2']='Szemöldök',['3']='Öregedés',['4']='Smink',['5']='Pír',['6']='Arcbőr',['7']='Napkárosodás',['8']='Rúzs',['9']='Szeplők',['10']='Mellkasszőr',['11']='Testhibák',['12']='Extra testhibák'}
local function deepcopy(x)if type(x)~='table'then return x end;local o={};for k,v in pairs(x)do o[k]=deepcopy(v)end;return o end
local function modelName(ped)local h=GetEntityModel(ped);if h==joaat('mp_f_freemode_01')then return'mp_f_freemode_01'end;return'mp_m_freemode_01'end
local function capture()
    local ped=PlayerPedId();local a={model=modelName(ped),components={},props={},faceFeatures={},overlays={},headBlend={shapeFirst=0,shapeSecond=0,skinFirst=0,skinSecond=0,shapeMix=.5,skinMix=.5},hair={color=0,highlight=0}}
    for i=0,11 do a.components[tostring(i)]={drawable=GetPedDrawableVariation(ped,i),texture=GetPedTextureVariation(ped,i),palette=GetPedPaletteVariation(ped,i)}end
    for i=0,7 do a.props[tostring(i)]={drawable=GetPedPropIndex(ped,i),texture=GetPedPropTextureIndex(ped,i)}end
    for i=0,19 do a.faceFeatures[tostring(i)]=0 end;for i=0,12 do a.overlays[tostring(i)]={index=0,opacity=0,color=0,colorType=(i==1 or i==2 or i==10)and 1 or 0}end
    return a
end
local function requestModel(m)local h=type(m)=='number'and m or joaat(m);RequestModel(h);local t=GetGameTimer()+8000;while not HasModelLoaded(h)and GetGameTimer()<t do Wait(0)end;return HasModelLoaded(h)and h or nil end
local function apply(a)
    if type(a)~='table'then return false end
    if a.model then local h=requestModel(a.model);if h then SetPlayerModel(PlayerId(),h);SetModelAsNoLongerNeeded(h)end end
    local ped=PlayerPedId();local hb=a.headBlend or{};SetPedHeadBlendData(ped,hb.shapeFirst or 0,hb.shapeSecond or 0,0,hb.skinFirst or 0,hb.skinSecond or 0,0,hb.shapeMix or .5,hb.skinMix or .5,0.0,false)
    if a.faceFeatures then for k,v in pairs(a.faceFeatures)do local id=tonumber(k);if id then SetPedFaceFeature(ped,id,tonumber(v)or 0.0)end end end
    if a.components then for k,v in pairs(a.components)do local id=tonumber(k);if id and type(v)=='table'then SetPedComponentVariation(ped,id,v.drawable or 0,v.texture or 0,v.palette or 0)end end end
    if a.props then for k,v in pairs(a.props)do local id=tonumber(k);if id and type(v)=='table'then if(v.drawable or-1)<0 then ClearPedProp(ped,id)else SetPedPropIndex(ped,id,v.drawable,v.texture or 0,true)end end end end
    local hair=a.hair or{};SetPedHairColor(ped,hair.color or 0,hair.highlight or 0)
    if a.overlays then for k,v in pairs(a.overlays)do local id=tonumber(k);if id and type(v)=='table'then local index=tonumber(v.index)or 0;SetPedHeadOverlay(ped,id,index,(tonumber(v.opacity)or 0)+0.0);if id==1 or id==2 or id==5 or id==8 or id==10 then SetPedHeadOverlayColor(ped,id,v.colorType or 1,v.color or 0,v.color or 0)end end end end
    return true
end
local function limits()
    local ped=PlayerPedId();local c,p={},{}
    for i=0,11 do local d=GetNumberOfPedDrawableVariations(ped,i);local tex={};for j=0,math.max(0,d-1)do tex[tostring(j)]=GetNumberOfPedTextureVariations(ped,i,j)end;c[tostring(i)]={drawables=d,textures=tex,label=componentNames[tostring(i)]}end
    for i=0,7 do local d=GetNumberOfPedPropDrawableVariations(ped,i);local tex={};for j=0,math.max(0,d-1)do tex[tostring(j)]=GetNumberOfPedPropTextureVariations(ped,i,j)end;p[tostring(i)]={drawables=d,textures=tex}end
    return{components=c,props=p,overlays=overlayNames}
end
local function camera(on)
    if on then
        if cam then DestroyCam(cam,false)end;local ped=PlayerPedId();local pos=GetEntityCoords(ped);local f=GetEntityForwardVector(ped)
        cam=CreateCam('DEFAULT_SCRIPTED_CAMERA',true);SetCamCoord(cam,pos.x+f.x*SzCoreAppearanceConfig.cameraDistance,pos.y+f.y*SzCoreAppearanceConfig.cameraDistance,pos.z+SzCoreAppearanceConfig.cameraHeight);PointCamAtCoord(cam,pos.x,pos.y,pos.z+0.62);SetCamFov(cam,35.0);RenderScriptCams(true,true,300,true,true)
    elseif cam then RenderScriptCams(false,true,250,true,true);DestroyCam(cam,false);cam=nil end
end
local function openCreator()
    if creator then return end;local saved=exports.szcore:AwaitCallback('szcore_appearance:get');current=deepcopy(saved or capture());original=deepcopy(current);outfits=exports.szcore:AwaitCallback('szcore_appearance:outfits') or{};apply(current);creator=true;FreezeEntityPosition(PlayerPedId(),true);camera(true);SetNuiFocus(true,true);SendNUIMessage({action='open',data=current,limits=limits(),outfits=outfits})
end
local function close(saveIt)
    if not creator then return end
    if saveIt then local ok,err=exports.szcore:AwaitCallback('szcore_appearance:save',current);exports.szcore_ui:Notify({type=ok and'success'or'error',description=ok and'Megjelenés elmentve.'or(err or'Mentési hiba.')})else apply(original)end
    creator=false;camera(false);FreezeEntityPosition(PlayerPedId(),false);SetNuiFocus(false,false);SendNUIMessage({action='close'})
end
local function setChange(d)
    if not creator or type(d)~='table'then return end;local k=tostring(d.id or'')
    if d.kind=='model'then current.model=d.value=='female'and'mp_f_freemode_01'or'mp_m_freemode_01';apply(current);SendNUIMessage({action='limits',limits=limits()})
    elseif d.kind=='component'then current.components[k]=current.components[k]or{};current.components[k][d.field]=tonumber(d.value)or 0;local v=current.components[k];SetPedComponentVariation(PlayerPedId(),tonumber(k),v.drawable or 0,v.texture or 0,v.palette or 0)
    elseif d.kind=='prop'then current.props[k]=current.props[k]or{};current.props[k][d.field]=tonumber(d.value)or 0;local v=current.props[k];if(v.drawable or-1)<0 then ClearPedProp(PlayerPedId(),tonumber(k))else SetPedPropIndex(PlayerPedId(),tonumber(k),v.drawable,v.texture or 0,true)end
    elseif d.kind=='face'then current.faceFeatures[k]=tonumber(d.value)or 0;SetPedFaceFeature(PlayerPedId(),tonumber(k),current.faceFeatures[k])
    elseif d.kind=='blend'then current.headBlend[d.field]=tonumber(d.value)or 0;apply(current)
    elseif d.kind=='hair'then current.hair[d.field]=tonumber(d.value)or 0;SetPedHairColor(PlayerPedId(),current.hair.color or 0,current.hair.highlight or 0)
    elseif d.kind=='overlay'then current.overlays[k]=current.overlays[k]or{index=0,opacity=0,color=0,colorType=0};current.overlays[k][d.field]=tonumber(d.value)or 0;apply(current)end
end
RegisterNetEvent('szcore_appearance:apply',apply)
AddEventHandler('szcore:client:spawned',function()SetTimeout(650,function()local a=exports.szcore:AwaitCallback('szcore_appearance:get');if a then apply(a)elseif SzCoreAppearanceConfig.openOnFirstCharacter then openCreator()end end)end)
RegisterNUICallback('change',function(d,cb)setChange(d);cb({ok=true})end);RegisterNUICallback('save',function(_,cb)close(true);cb({ok=true})end);RegisterNUICallback('cancel',function(_,cb)close(false);cb({ok=true})end)
RegisterNUICallback('saveOutfit',function(d,cb)local ok,err=exports.szcore:AwaitCallback('szcore_appearance:saveOutfit',d.name,current);if ok then outfits=exports.szcore:AwaitCallback('szcore_appearance:outfits')or{};SendNUIMessage({action='outfits',outfits=outfits})end;cb({ok=ok,error=err})end)
RegisterNUICallback('deleteOutfit',function(d,cb)local ok=exports.szcore:AwaitCallback('szcore_appearance:deleteOutfit',d.id);if ok then outfits=exports.szcore:AwaitCallback('szcore_appearance:outfits')or{};SendNUIMessage({action='outfits',outfits=outfits})end;cb({ok=ok})end)
RegisterNUICallback('wearOutfit',function(d,cb)local a=exports.szcore:AwaitCallback('szcore_appearance:getOutfit',d.id);if a then current=deepcopy(a);apply(current);SendNUIMessage({action='appearance',data=current,limits=limits()})end;cb({ok=a~=nil})end)
RegisterNUICallback('rotate',function(d,cb)local p=PlayerPedId();SetEntityHeading(p,GetEntityHeading(p)+(tonumber(d.delta)or 0));camera(true);cb({ok=true})end)
if SzCoreAppearanceConfig.allowCommand then RegisterCommand(SzCoreAppearanceConfig.command,openCreator,false)end
exports('ApplyAppearance',apply);exports('SaveAppearance',function(data)return exports.szcore:AwaitCallback('szcore_appearance:save',data)end);exports('OpenCreator',openCreator)
