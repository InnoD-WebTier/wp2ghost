fs = require 'fs'
xml = require 'xml2js'
csv = require 'csv-parse'
slugs = require 'slug'
uuid = require 'uuid'
tomd = require('to-markdown').toMarkdown
Promise = (require 'bluebird').Promise
_ = require('lodash')

posts = fs.readFileSync('posts.xml')
users = {}

now = () ->
    return new Date().getTime()

findID = (user) ->
    if user is ''
        return 1
    if users[user]?
        return parseInt(users[user].ID)
    throw "No user found"

toTitleCase = (str) ->
    str.replace /\w\S*/g, (txt) ->
        txt[0].toUpperCase() + txt[1..txt.length - 1].toLowerCase()

parseUser = (user) ->
    if user.first_name == undefined && user.display_name == undefined
        return

    givenName = 'NO NAME'
    if (user.first_name && user.first_name.length && user.last_name && user.last_name.length) 
        fullName = ("#{user.first_name} #{user.last_name}")
        givenName = toTitleCase(fullName)
    else 
        if (user.display_name.split(' ').length > 1)
            givenName = toTitleCase(user.display_name)
        else
            givenName = user.display_name

    if !user.user_email || user.user_email.length == 0
        user.user_email = 'fixme@fixme.fixme';
        givenName = '__' + givenName;


    return {
        id: 1000 + parseInt(user.ID)
        name: givenName
        slug: user.user_nicename
        email: user.user_email
        image: null
        cover: null
        bio: if user.description then user.description.substring(0, 200) else ''
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
    post_content = post['content:encoded'][0]
    post_title = post.title[0]
    if post_content.length == 0
        return
    if post_title.lengt == 0
        post.title[0] = 'NO TITLE ' + uuid.v4()

    regexes = [
        /\[caption.*?width=["'](\d+)["'].*?(<([a-z]+)\s+.+?(?:\/>)(?:.+?\/\3>)?)\s*(.*?)\[\/caption\]/g,
        /\[caption.*?width=["'](\d+)["'].*?caption=["']([^"']*)["'].*?(<[a-z]+\s+.+?\/>)\[\/caption\]/g,
        /(.*?)<(b|em|i|small|strong|sub|sup|ins|del|mark)>([\s\n]*)(.*?)([\s\n]*)<\/\2>(.*)/g,
        /(<div.*?>)+(<img.*\/>)(<\/div>)+/g,
        /<div><\/div>/g,
    ]

    replacements = [
        '<center>$2\n<small>$4</small></center>',
        '<center>$3\n<small>$2</small></center>',
        '$1$3<$2>$4</$2>$5$6',
        '$2',
        '',
    ]

    _.forEach(regexes, (regex, i) ->
      post_content = post_content.replace(regex, replacements[i])
    )

    return {
        id: parseInt(post['wp:post_id'][0])
        title: post.title[0]
        slug: slugs(post.title[0])
        markdown: tomd(post_content)
        html: post_content
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

        parsedUsers = _.compact(parseUser(users[user]) for user in Object.keys(users))
        parsedPosts = _.compact(parsePost(post) for post in posts)
        usersWithPosts = _.filter(parsedUsers, (user) ->
          user_id = user.id
          for post in parsedPosts
            if user.id == post.author_id
              return true
          return false
        )

        output =
            meta:
                exported_on: now()
                version: '003'
            data:
                posts: parsedPosts
                tags: (tags[tag] for tag in Object.keys(tags))
                posts_tags: post_tags
                users: usersWithPosts
                roles_users: []

        console.log JSON.stringify(output)

        
