# Heroic SNS Endpoint

This gem contains a lightweight Rack middleware for AWS Simple Notification
Service (SNS) endpoints.

SNS messages to your web application are intercepted, parsed, verified, and then
passed along to your Rack application in the `sns.message` environment key.

If something goes wrong, the error will be passed along in the `sns.error`
environment key. `Endpoint` does not log any messages itself.

This gem *does not* depend on [aws-sdk][]. In fact, the only dependency it has
beyond the standard libraries is [rack][]. This is intentional, since AWS
credentials are not required to receive SNS notifications.

[aws-sdk]: https://github.com/aws/aws-sdk-ruby
[rack]: http://rack.github.io/

## Overview

1. Install in your middleware stack
2. Get SNS messages from `env['sns.message']`
3. Get errors from `env['sns.error']`

## How to use it

Simply add the following to your `config.ru` file:

    use Heroic::SNS::Endpoint, :topics => /:aws-ses-bounces$/

For Rails, you could also install it in `/config/initializers/sns_endpoint.rb`:

    Rails.application.config.middleware.use Heroic::SNS::Endpoint, :topic => ...

The Endpoint class takes an options hash as an argument, and understands these
options:

`:topic` is required, and provides a filter that defines what SNS topics are
handled by this endpoint. A message is considered either "on-topic" or
"off-topic". You can supply any of the following:

- a single topic ARN as a `String`
- a list of topic ARNs as an `Array` of `String`
- a `RegExp` which matches on-topic ARNs
- a `Proc` which accepts an ARN as an argument and returns `true` or `false` for
  on-topic and off-topic ARNs, respectively.

The key `topics:` also works.

`:auto_confirm` affects how on-topic subscription confirmations are handled.

- If `true`, they are confirmed by retrieving the URL in the `SubscribeURL` field
  of the SNS message, and your app is not notified.
- If `false`, they are ignored; your app is also not notified.
- If `nil`, there is no special handling and the message is passed along to your
  app.
  
The default is `true`.

`:auto_resubscribe` affects how on-topic unsubscribe confirmations are handled.

- If `true`, they topic is automatically re-subscribed by retrieving the URL in
  the `SubscribeURL` field of the SNS message, and your app is not notified.
- If `false`, they are ignored and your app is also not notified.
- If `nil`, there is no special handling and the message is passed along to your
  app.

The default is `false`.

If you are a control-freak and want no special handling whatsoever, use these
options:

    use Heroic::SNS::Endpoint, :topics => Proc.new { true }, :auto_confirm => nil, :auto_resubscribe => nil

Then the object will simply parse and verify SNS messages it finds and pass them
along to your app, taking no action.

Once the middleware is set up, any notifications will be made available in your
Rack environment under the `sns.message` key. If you are using Rails, your
controller would have a method like this:

    skip_before_filter :verify_authenticity_token, :only => [:handle_notification]

    def handle_notification
      if message = request.env['sns.message']
        # message is an instance of Heroic::SNS::Message
        payload = JSON.parse(message.body)
        do_something_awesome(payload)
      elsif error = request.env['sns.error']
        raise error # let the warning be logged
      end
      head :ok
    end

You must skip the authenticity token verification to allow Amazon to POST to the
controller action. Be careful not to disable it for more actions than you need.
Be sure to disable any authentication checks for that action, too.

## How off-topic notifications are handled

As a security measure, `Endpoint` requires you to set up a topic filter. Any
notifications that do not match this filter are not passed along to your
application.

All off-topic messages are ignored with one exception: if the message is a
regular notification (meaning your app has an active subscription) *and* the
message can be verified as authentic (by checking its signature), `Endpoint`
will cancel the subscription by visiting the URL in the `UnsubscribeURL` field
of the message.

If you would rather make decision about on-topic and off-topic notifications in
your own code, simply pass `Proc.new { true }` as the topic filter, and all
messages will be treated as on topic. Be aware that it is dangerous to leave
`:auto_confirm` enabled with a permissive topic filter, as this will allow
anyone to subscribe your web app to any SNS notification.

## Receiving multiple notification topics

If you are receiving multiple notifications at multiple endpoint URLs, you should
only include one instance of the Endpoint in your middleware stack, and ensure
that its topic filter allows all the notifications you are interested in to pass
through.

`Endpoint` does not interact with the URL path at all; if you want your
subscriptions to go to different URLs, simply set them up that way.

## Questions?

You can send me an email at <ben@benzado.com> or Twitter [@benzado][]

[@benzado]: https://twitter.com/benzado

[![Build Status](https://travis-ci.org/benzado/heroic-sns.png?branch=master)](https://travis-ci.org/benzado/heroic-sns)
