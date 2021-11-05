local checks = require('checks') -- для проверки аргументов функций

local function init_spaces()
    local link = box.schema.space.create(
        'link',
        {
            format = {
                {'uuid', 'string'},
                {'link', 'string'},
            },
            if_not_exists = true,
            engine = 'memtx',
        }
    )

    link:create_index('uuid', {
        parts = {'uuid'},
        if_not_exists = true,
    })

end

local function link_add(link)
    box.space.link:insert({
        link.uuid,
        link.link
    })

    return true
end

local function link_get(uuid)
    checks('string')

    local link = box.space.link:get(uuid)

    if link == nil then
        return nil
    end

    return link[2]
end

local function init(opts)
    if opts.is_master then

        init_spaces()

        box.schema.func.create('link_add', {if_not_exists = true})
        box.schema.func.create('link_get', {if_not_exists = true})

    end

    rawset(_G, 'link_add', link_add)
    rawset(_G, 'link_get', link_get)

    return true
end

return {
    role_name = 'links_cache',
    init = init,
    dependencies = {
        'cartridge.roles.vshard-storage',
    },
    utils = {
        link_add = link_add,
        link_get = link_get,
    }
}