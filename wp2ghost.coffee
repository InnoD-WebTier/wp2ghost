fs = require 'fs'
xml = require 'xml2js'
csv = require 'csv-parse'
slugs = require 'slug'
uuid = require 'uuid'
tomd = require('to-markdown').toMarkdown
Promise = (require 'bluebird').Promise

posts = fs.readFileSync('posts.xml')
users = {}

now = () ->
    return new Date().getTime() / 1000

findID = (user) ->
    if user is ''
        return 1
    if users[user]?
        return parseInt(users[user].ID)
    throw "No user found"

parseUser = (user) ->
    if user.user_email.length == 0
        user.user_email = uuid.v4() + 'noemail@email.com'

    return {
        id: 1000 + parseInt(user.ID)
        name: if user.first_name.length and user.last_name.length then "#{user.first_name} #{user.last_name}" else user.display_name
        slug: user.user_nicename
        email: user.user_email
        image: null
        cover: null
        bio: user.description.substring(0, 200)
        website: user.user_url
        location: null
        accessibility: null
        status: 'active'
        language: 'en_US'
        meta_title: null
        meta_description: null
        last_login: null
        created_at: new Date(user.user_registered).getTime()
        created_by: 1
        updated_at: new Date(user.user_registered).getTime()
        updated_by: 1
    }

parsePost = (post) ->
    creator = 1000 + findID(post['dc:creator'][0])
    if post.title[0].length == 0
        post.title[0] = 'NO TITLE' + uuid.v4()

    return {
        id: parseInt(post['wp:post_id'][0])
        title: post.title[0]
        slug: slugs(post.title[0])
        markdown: tomd(post['content:encoded'][0])
        html: post['content:encoded'][0]
        image: null
        featured: 0
        page: 0
        status: 'published'  
        language: 'en_US'
        meta_title: null
        meta_description: null
        author_id: creator
        created_at: new Date(post['wp:post_date'][0]).getTime()
        created_by: creator
        updated_at: new Date(post['wp:post_date'][0]).getTime()
        updated_by: creator
        published_at: new Date(post['wp:post_date'][0]).getTime()
        published_by: creator
    }

xml.parseString posts, (err, result) ->
    data = result.rss.channel[0]
    posts = data.item.filter((item) -> item['wp:status'][0] == 'publish')

    csv fs.readFileSync('users.csv'), {columns: true}, (err, result) -> 
        users = result.reduce ((dict, obj) -> dict[obj['user_login']] = obj if obj['user_login']?; return dict;), {}

        tags = {}
        post_tags = []
        tag_id = 1
        pushTag = (tag) ->
            if not tags[tag]?
                tags[tag] = {
                    id: tag_id
                    name: tag
                    slug: slugs(tag)
                    description: ''
                }
                tag_id++
        (((((pushTag(cat.$.nicename); post_tags.push({tag_id: tags[cat.$.nicename].id, post_id: parseInt(post['wp:post_id'][0])})) if cat.$.domain is 'post_tag') for cat in post.category) if post.category?) for post in posts)

        output =
            meta:
                exported_on: now()
                version: '003'
            data:
                posts: (parsePost(post) for post in posts)
                tags: (tags[tag] for tag in Object.keys(tags))
                posts_tags: post_tags
                users: (parseUser(users[user]) for user in Object.keys(users))
                roles_users: []

        users_with_posts = (post.author_id for post in output.data.posts)
        nf = (user_id) ->
            for user in output.data.users
                if user.id == user_id
                    return user

        Array::unique = ->
            out = {}
            out[@[key]] = @[key] for key in [0...@length]
            value for key, value of out
        users_with_posts = users_with_posts.unique()
        # console.log users_with_posts

        new_users = (nf(user) for user in users_with_posts)
        # console.log new_users
        output.data.users = new_users
        console.log JSON.stringify(output)

        
