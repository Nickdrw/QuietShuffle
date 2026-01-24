-- Minimal LibStub implementation
local LibStub = _G.LibStub or { libs = {}, minors = {} }

function LibStub:NewLibrary(major, minor)
    assert(type(major) == "string", "Bad argument #1 to `NewLibrary' (string expected)")
    minor = assert(tonumber(tostring(minor):match("%d+")), "Minor version must be a number")

    local oldminor = self.minors[major]
    if oldminor and oldminor >= minor then
        return nil
    end

    self.minors[major] = minor
    self.libs[major] = self.libs[major] or {}
    return self.libs[major], oldminor
end

function LibStub:GetLibrary(major, silent)
    local lib = self.libs[major]
    if not lib and not silent then
        error(("Cannot find a library instance of %q."):format(tostring(major)), 2)
    end
    return lib, self.minors[major]
end

function LibStub:IterateLibraries()
    return pairs(self.libs)
end

setmetatable(LibStub, { __call = LibStub.GetLibrary })
_G.LibStub = LibStub
