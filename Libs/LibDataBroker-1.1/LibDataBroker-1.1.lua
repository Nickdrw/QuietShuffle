assert(LibStub, "LibDataBroker-1.1 requires LibStub")

local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 1)
if not lib then return end

lib.dataObjects = lib.dataObjects or {}

function lib:NewDataObject(name, dataobj)
    if not name or type(name) ~= "string" then
        error("Usage: NewDataObject(name, dataobj)", 2)
    end
    if lib.dataObjects[name] then
        return lib.dataObjects[name]
    end
    dataobj = dataobj or {}
    lib.dataObjects[name] = dataobj
    return dataobj
end

function lib:GetDataObjectByName(name)
    return lib.dataObjects[name]
end

function lib:DataObjectIterator()
    return pairs(lib.dataObjects)
end
