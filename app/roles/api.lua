local cartridge = require('cartridge')
local errors = require('errors')

local err_vshard_router = errors.new_class("Vshard routing error")
local err_httpd = errors.new_class("httpd error")

local charset = {}

-- qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890
for i = 48,  57 do table.insert(charset, string.char(i)) end
for i = 65,  90 do table.insert(charset, string.char(i)) end
for i = 97, 122 do table.insert(charset, string.char(i)) end

function string.random(length)
    math.randomseed(os.time())

    if length > 0 then
        return string.random(length - 1) .. charset[math.random(1, #charset)]
    else
        return ""
    end
end

local function verify_response(response, error, req)

    -- внутренняя ошибка
    if error then
        local resp = req:render({json = {
            info = "Internal error",
            error = error
        }})
        resp.status = 500
        return resp
    end

    if response == nil then
        local resp = req:render({json = {
            info = "Link not found",
            error = error
        }})
        resp.status = 404
        return resp
    end

    return true
end

local function http_link_add(req)
    local link = req:json()['link']
    local uuid = string.random(8)
    local router = cartridge.service_get('vshard-router').get()
    local bucket_id = router:bucket_id('id')

    local link_obj = {link=link, uuid=uuid}

    local success, error = err_vshard_router:pcall(
        router.call,
        router,
        bucket_id,
        'write',
        'link_add',
        {link_obj}
    )

    local resp = req:render({text = 'http://89.208.198.209:8081/' .. link_obj.uuid})
    resp.status = 201
    return resp
end

local function http_link_get(req)
    local uuid = req:stash('uuid')
    local router = cartridge.service_get('vshard-router').get()
    local bucket_id = router:bucket_id(uuid)

    
    local link, error = err_vshard_router:pcall(
        router.call,
        router,
        bucket_id,
        'read',
        'link_get',
        {uuid}
    )
    

    local verification_status = verify_response(link, error, req)
    if verification_status ~= true then
        return verification_status
    end

    local resp = req:render({ json = {} })
    resp.status = 301
    resp.headers['Location'] = link
    return resp
end


local function init(opts)

    if opts.is_master then
        box.schema.user.grant('guest',
            'read,write,execute',
            'universe',
            nil, { if_not_exists = true }
        )
    end

    local httpd = cartridge.service_get('httpd')

    if not httpd then
        return nil, err_httpd:new("not found")
    end

    -- назначение обработчиков
    httpd:route(
        { path = '/set', method = 'POST', public = true },
        http_link_add
    )
    httpd:route(
        { path = '/:uuid', method = 'GET', public = true },
        http_link_get
    )

    return true
end

return {
    role_name = 'api',
    init = init,
    dependencies = {'cartridge.roles.vshard-router'},
}