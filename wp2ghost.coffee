fs = require 'fs'
xml = require 'xml2js'
csv = require 'csv-parse'
slugs = require 'slug'
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
    return {
        id: 1000 + parseInt(user.ID)
        name: if user.first_name.length and user.last_name.length then "#{user.first_name} #{user.last_name}" else user.display_name
        slug: user.user_nicename
        email: user.user_email
        image: null
        cover: null
        bio: user.description
        website: user.user_url
        location: null
        accessibility: null
        status: 'active'
        language: 'en_US'
        meta_title: null
        meta_description: null
        last_login: null
        created_at: new Date(user.user_registered).getTime() / 1000
        created_by: 1
        updated_at: new Date(user.user_registered).getTime() / 1000
        updated_by: 1
    }

parsePost = (post) ->
    creator = 1000 + findID(post['dc:creator'][0])
    
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
        created_at: new Date(post['wp:post_date'][0]).getTime() / 1000
        created_by: creator
        updated_at: new Date(post['wp:post_date'][0]).getTime() / 1000
        updated_by: creator
        published_at: new Date(post['wp:post_date'][0]).getTime() / 1000
        published_by: creator
    }

xml.parseString posts, (err, result) ->
    data = result.rss.channel[0]
    posts = data.item

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

        console.log output.data

        
