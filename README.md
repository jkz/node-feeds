This is not production ready in ANY way.
I advice waiting for a 0.1.0 release to let it
anywhere near your code.

# Feeds

Expose paginated feeds of anything as websocket, webhook or event emitter.
Uses redis to store the feed entries references and optionally cache the data.
The stored references allow for careless backfilling after downtime or otherwise
missed data entries.

# Aggregators

Aggregators combine multiple Feeds as a single one. They keep their own log of
references while utilizing the existing Feed caches.

# Consume

The feeds can be consumed in code by using them as EventEmitters.
There are some express bindings in `feeds/feeds/resource` to query
with various pagination methods.
It's also trivial to set up a socket feed.

## Why would one use this?

It makes it really easy to turn any information into a paginated feed.
Having feeds as lightweight datastructures, you can start building data
highways with lots of lanes, junctions and "coming-together-of-roads"s (please
tweet me the word for this @jessethegame if you know it)

## How would one use this?

E.g. combine twitter and github stories into a single feed.

    // Create a feed of tweets
    var feeds = require('feeds').models;
    var twitter = require('some-twitter-lib');
    var github = require('some-github-lib');
    var io = require('socket.io')

    // This is a feed of github events
    var twitterFeed = models.JSONFeed.create('twitter', {
      generateId: function (data) { data.id },
      generateTimestamp: function (data) { data.created_at }
    });

    twitter.createStream(..., ...).on('tweet', feed.add);

    // This is a feed of github events
    var githubFeed = models.JSONFeed.create('github', {
      generateId: function (data) { data.id },
      generateTimestamp: function (data) { data.timestamp }
    });

    github.pollEvents(..., ...).on('event', feed.add);

    // This is a combined feed of tweets and github events
    var twithubFeed = models.Aggregator.create('twithub');
    twithub.combine(twitterFeed);
    twithub.combine(githubFeed);

    // Expose the data over a websocket
    twithubFeed.on('data', function (data) {
      io.emit('data', data)
    });

    io.listen(3000)

## Roadmap

* Atom support
* RSS support
* Connect support (rather than express)

## LICENSE

MIT license. See the LICENSE file for details.
