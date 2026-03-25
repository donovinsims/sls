CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE public.videos
  ADD COLUMN IF NOT EXISTS transcript text NOT NULL DEFAULT '';
ALTER TABLE public.videos
  ADD COLUMN IF NOT EXISTS summary text NOT NULL DEFAULT '';

UPDATE public.videos
SET transcript = COALESCE(transcript, ''),
    summary = COALESCE(summary, '');

CREATE TABLE IF NOT EXISTS public.video_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  video_id uuid NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  session_token text NOT NULL,
  ip_address text,
  device_fingerprint text,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  used boolean NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.activity_log (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  video_id uuid NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  ip_address text,
  event_type text NOT NULL,
  watched_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.video_progress (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  video_id uuid NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  completed boolean NOT NULL DEFAULT false,
  last_watched_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS video_sessions_session_token_uidx
  ON public.video_sessions (session_token);
CREATE UNIQUE INDEX IF NOT EXISTS video_progress_customer_video_uidx
  ON public.video_progress (customer_id, video_id);

ALTER TABLE public.video_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.video_progress ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'video_sessions' AND policyname = 'Service role full access video_sessions'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "Service role full access video_sessions"
      ON public.video_sessions
      FOR ALL
      USING (auth.role() = 'service_role')
    $policy$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'activity_log' AND policyname = 'Service role full access activity_log'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "Service role full access activity_log"
      ON public.activity_log
      FOR ALL
      USING (auth.role() = 'service_role')
    $policy$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'video_progress' AND policyname = 'Service role full access video_progress'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "Service role full access video_progress"
      ON public.video_progress
      FOR ALL
      TO public
      USING (auth.role() = 'service_role')
    $policy$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'video_progress' AND policyname = 'Authenticated users can read own progress'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "Authenticated users can read own progress"
      ON public.video_progress
      FOR SELECT
      TO authenticated
      USING (
        customer_id IN (
          SELECT id FROM public.customers WHERE email = lower(auth.jwt() ->> 'email')
        )
      )
    $policy$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'video_progress' AND policyname = 'Authenticated users can upsert own progress'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "Authenticated users can upsert own progress"
      ON public.video_progress
      FOR INSERT
      TO authenticated
      WITH CHECK (
        customer_id IN (
          SELECT id FROM public.customers WHERE email = lower(auth.jwt() ->> 'email')
        )
      )
    $policy$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'video_progress' AND policyname = 'Authenticated users can update own progress'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "Authenticated users can update own progress"
      ON public.video_progress
      FOR UPDATE
      TO authenticated
      USING (
        customer_id IN (
          SELECT id FROM public.customers WHERE email = lower(auth.jwt() ->> 'email')
        )
      )
    $policy$;
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.get_course_videos()
RETURNS TABLE (
  id uuid,
  title text,
  description text,
  sort_order int,
  module text,
  summary text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT v.id, v.title, v.description, v.sort_order, v.module, v.summary
  FROM public.videos v
  ORDER BY v.sort_order ASC;
$$;

-- Backfill watch-page content for lesson 1: START HERE!
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_01_transcript$Welcome to the SLS Trading course. In this first lesson, Shea explains how to use the course, why the lessons build on each other, and how to approach the material in order. The goal is to start with the basics, build confidence step by step, and turn the course into one complete process instead of a collection of random trading tips.$video_01_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_01_summary$This is your starting point. Before you dive into charts, setups, or strategies, this video sets the stage for everything that follows. You will learn how to get the most out of this course, what to expect from each module, and the right mindset to bring to your first lesson. Think of this as your orientation - a few minutes that will save you hours of confusion later.$video_01_summary$
      ELSE summary
    END
WHERE sort_order = 1
  AND title = $title_01$START HERE!$title_01$;

-- Backfill watch-page content for lesson 2: Course Overview
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_02_transcript$This lesson walks through how the course strategy fits together from the higher time frames down to the lower ones. Shea explains how to prep for trades, how the modules connect, and how to use the later lessons as part of one repeatable trading framework.

Hey everyone. So, uh, welcome to the


strategy video. In this video, I'm going


to show you how I prep for my trades


using top down analysis. So, we're going


to start with the higher time frames and


then work our way down to the lower time


frame. Um, I personally like to scalp


the 1 and 5 minute, but we'll just kind


of I'll show you different time frames.


Um, so, you know, we'll get down to the


lower ones. That way we can, you know,


find clean entries and kind of pinpoint


where exactly we want to get in. So, let


me share my screen with you.


Okay, so here we have,


let me get this out of my way.


Uh, we have a NAS trade. So, um, I kind


of wanted to find an area that was near


a support and resistance. That way, once


we get down to these lower time frames,


I can kind of, you know, show you when I


would enter. So, first thing we're going


to do is we're going to hop on to


the higher time frame. And I personally


just start with the 4our time frame. So,


what you want to do,


let me I'll go and get these off of


here. That way


you can kind of see it with my eyes.


Okay. So, what I want to look for is


areas of hesitation. So whether that be,


you know, where I see price kind of


having a hard time getting above or


getting below. Uh so that's what I want


to mark off as support and resistance.


So with the 4hour time frame, I will use


um a top and a bottom line.


And if you want to kind of think of it


as, you know, a ceiling and a floor.


So, we're going to use the horizontal


line that we put on our chart in the


previous videos.


And


you can kind of see price had a hard


time getting past here. So, you know,


you can see came down, try to come back


up, and I like to mark mine


on the candle. So, even though, you


know, we have some wicks coming up here,


I want to mark off where price stopped.


So,


we're going to put our top resistance


there.


And then for the bottom one,


we're going to do the same thing. So,


we're going to kind of see where price


had a hard time getting past.


And I tried to look at


previous day first.


and kind of see if there was an area


that price had a hard time getting past.


But sometimes you won't see that,


especially if price is really moving.


And that's okay. You can go back


further,


you know. So I kind of see this area


right here.


It kind of got touched multiple times.


Had a hard time getting past here.


finally broke through. Hard time getting


below it.


And then you can kind of see it


accumulating.


And then same thing. So, you know, if


you kind of shrink your screen up


and sometimes you can shrink it up and


go really far, you know, back. it. But


if you just shrink it up, you can kind


of see,


you know, where it kind of creates this


zone.


So once I have that on my chart and I


well, let me get down to a lower time


frame and then I'll put that on there.


Um, okay. So then after I get my 4hour


support and resistance


then I will go down to the 1 hour


and I'll do the same thing.


And just remember, you can kind of


shrink your screen down


however you need to do it to where your


eyes kind of


see an area.


So you can see if I have my


cursor right there,


you can kind of see that it's hitting


this area multiple times


all the way back. I mean, you can follow


that back to July 3rd.


You know, sometimes it broke past it and


came back down and but you can just see


it hit it multiple times.


So my 1 hour I will make a red color and


I usually will only do one area of


hesitation


for the 1 hour and for the 15 minute as


well.


Okay. So once we have that then we will


jump down to the 15minute


and we will do the same thing.


Okay. So, we'll kind of get our cursor.


If I put that there, I'm going to do


this one in orange.


Can you see how


price kind of pinged off of this


multiple times? this little area right


here.


Okay. So now that we have that,


let me


Okay, so my 4 hour


just in case you want your chart to look


like mine,


1 hour,


red,


15 A minute.


Orange.


Okay.


Actually, let's go ahead and label this


so you know what it is.


support, which is the


bottom.


And just think if something is


supporting something, it's usually


underneath holding it up.


Resistance


is the top. It's usually what you think


of something stopping it from, you know,


pushing past the top.


Okay. So, 4 hour I do a support


and a resistance


and then the 1 hour.


I think I always just call it a


resistance area, but whatever you want


to call it,


hesitation


area.


And same thing


one


resistance line


vegetation area.


Same with this one.


Okay.


So now that we have our


support and resistance from the 4 hour,


our resistance area from the 1 hour, and


our resistance area from the 15minute,


then we can


jump down to the lower time frame and


I'll kind of show you.


And sometimes you can adjust them if you


need to once you kind of get down to


these lower time frames.


But you can kind of see price just


came up and down and up and down and


kind of stayed in these little valleys.


So


and then if I see,


you know, so if you think of whenever we


were like on the 4hour time frame and I


was saying that I like to mark it off at


the candle body and not the wick.


There's uh times that the wicks are just


something like this, just a liquidity


grab. So, it's just going to shoot a


quick wake up to stop people out, the


small retail traders,


and then come right back down in its


intended direction. So, that's


personally why I just don't like marking


off the wicks.


So to give you a visualization of what


that looks like on the lower time frames


and then one step further I'll show you


what it looks like on the one minute.


So you can kind of see right here price


came up and then once it got to that 1


hour area


we just had a lot of accumulation right


here.


Okay. But for now, just so the candles


are a little bit bigger,


I will start with the 15minute


and we'll see if we get a fair value


gap,


which there's one right there, but price


already came down. So,


okay. So, I'm going to push play and


then we're just going to kind of see how


this plays out. I will pause it, let you


know what I'm looking for, and if I see


something that looks like a potentially


good trade, then we'll pause and we'll


mark it up and get into it. So, we're


going to go and push play.


Okay. So, I'm going to go ahead and


pause that just because I see a fair


value gap pop up.


So, whenever price came down to this


bottom support area,


you can see these candles had a hard


time getting past it. And of course,


just because it came up,


I don't want to immediately get into the


trade. So my 9 EMA, which is this black


one, and my 21, which is this orange


one, I want to see them cross. Um, that


is a very good confluence for me. Uh,


that price is shifting and


you know that we potentially are going


to either have a continuation or a


reversal. So, the fact that my 9 EMA is


still below the 21,


I would not want to get into a buy yet


until this crossed. So,


I see that price came above my support,


rejected. This could just be a liquidity


grab. So, we see it coming up.


the 9 EMA still below the 21. So, we'll


wait and see if it crosses. If you want


to wait until it crosses on the 15minut


time frame,


you can. I of course with it being a


higher time frame, it takes a lot more


price movement to get that to cross. So,


it's a little bit as of a I guess safer


move. So, you can do that. Of course, if


you watch it cross on the five minute or


the one minute,


price is going to fluctuate a lot more


on those time frames. Uh, but of course,


you'll get in the trade a little bit


quicker. Not a whole lot quicker, but so


it's just up to you, whatever you feel


comfortable with.


Okay. So, I'm going to go ahead and grab


my rectangle


tool


and I am going to mark off this fair


value gap.


Let me get this off real quick.


And I will go through and you know


there'll be more videos added to the um


the training education space I believe


is what it's called. Um,


and we'll kind of dive a little bit


deeper into fair value gaps, what causes


them, you know, what I watch for with


them, and of course, I'll go into a


little bit more about support and


resistance. So, you know, I'll kind of


break those down a little bit more in


the following videos,


but for now,


I want to see a fair value gap, which


will consist of three candles, three


consecutive candles. So, we have this


candle right here, and then we had a big


push in price and then a next candle. So


when there is a gap between this first


candle and this third candle


that is a fair value gap


and


usually price will want to come back and


fill the orders


that did not get filled when it had that


big push up in price. So kind of think


of it as a magnet. Uh you know price may


keep going but at some point it could


come down fill the orders


that were kind of left behind


and then go back in its intended


direction. So,


I don't know. Maybe an easy way to think


of it is say you're in a big group chat


with a bunch of people and somebody asks


three different questions. You know, are


we going out tonight? What are you


wearing? What do you want to eat? And


everybody starts answering and you know,


I'm wearing a dress. I want, you know, I


want to eat Mexican. But they missed


that third question. So an hour later,


somebody may come back and


answer that third question. So um you


know just think of it kind of like that


you know if you want to. So the


conversation kept going and then oh


forgot to answer that other question.


They came back to that initial


conversation thread and then the


conversation continued. So,


we want to go ahead and mark this off.


And I do if it is a green candle in the


middle, which is showing me


the direction,


then we will call that.


Hold on. I don't want that.


There we go. Okay. So we will call this


a bullish


fair value gap. Bullish is going up.


And then


right here on the tool colors, you can


come down and color it green. And then


same thing, you can fill it in green.


That way, if your eyes are just seeing a


fair value gap on your screen, you'll


know if price comes down and fills this,


you are going to be looking for buys uh


to go long,


bullish, whatever you want to call it,


but you're going to want to be going in


this direction. if price fills it but


doesn't come through and continues in


that intended bullish direction.


Okay. So once we have that


that's really you can continue to watch


it on the 15minute if you choose to. I


am going to hop down


to these lower time frames.


That way I can kind of show you some


other confluences


that I look for.


So you can see


for instance if I was on the one minute


time frame


you can see whenever price came up


and crossed my 4hour support


came down rejected came back up my EMA


had already crossed down here on this


one minute and of course when we have


pullbacks you'll see it come back to


that 21 EMA.


get away from it, come back because just


the price will fluctuate a lot more on


that one minute.


Same thing on the 5m minute. You can see


it crossed right here.


And then


at the same time,


I want to see


a W or


That is another confluence that


I really you know


want I guess to see um


if a trade can check off every


confluence that I have then


it's even better. So,


let me


show you this W


right here. So, there's a big one.


That's a thick line


right here.


And then price


continued up.


Okay, so


we have rejected off the 4hour support


continuation


crossing of the EMA,


a W which is showing us an uptrend.


We have a fair value gap


and then so let's see we're on the five


minute and then


get this off here so we can see this


better.


You can see we started creating


some higher highs.


some higher lows.


So, those are all good signs that we are


possibly going into an uptrend.


And then we can hop down to the one


minute. See if we see any W's on here as


well.


See right here.


You make that line a little bit thinner.


You can see that W right there.


And then I had you put the line chart on


your screen.


So, I'm going to switch to that.


And if you need to flip over to this to


kind of train your eyes to see the W's a


little bit better, then nothing wrong


with that. You can see there's a


W right there.


Okay.


Let's go back and


put that back where we want it.


Okay. So whenever I see a


bullish fair value gap down here near


this support


or same thing if it's up here by you


know the top resistance area


that shows me a you know strong sign


that price could go up. So, you know,


cuz we have it rejecting off this bottom


support, price will come down, tap in or


fill this fair value gap


and just I know some probably are okay


trading on the 1 minute, some maybe want


to stay on the 15minute.


Either is fine. I'm going to kind of go


in the middle


and


I would be good to enter.


So where price is right here you can see


this candle


whenever price went and broke that area


which is a break of structure. So, it's


showing continuation.


Broke past this previous high


and we're going to continue up. So, once


I see that break and of course my 9 EMA


crossed the 21,


I would feel comfortable getting in


this. So, I saw my W


price rejected off this bottom support.


We had the fair value gap that got


tapped into with this little candle


right there


and then we had a break of structure.


So,


let's see. This candle broke it.


So, I probably would have gotten in


around there if I was watching this


live. So


around


6:25


somewhere around there


my stop loss just to be safe I want to


put it below


the previous low. So, I'm going to get


it below this fractal.


And then, let me if I can


I'm going to bring this back just a


little bit.


about to where I would have gotten in.


Okay. So, you can either


initially aim for


the next area of hesitation, which is


this 15 minute.


I usually will always go for the 1 hour


or possibly the 4 hour, but I'll usually


start at the 1 hour. It holds a little


bit more weight than the 15minute, but


putting it at the 15minute initially,


you will be into profit. And then you


can move your stop loss up and if it


continues then you can adjust to the one


hour if you choose to. So, if you were


to do that, I would put an alert


right in here


and then that way you would get an alert


whenever price was getting close to that


15minute area and you would know, okay,


let me move my stop loss up to break


even or in profit and then move my


takeprofit up at the same time. So if


you want to kind of think of you know


this we have said this is kind of the


bottom support the floor this 4hour top


area is the resistance kind of the top


ceiling and then you know so that's kind


of what


I guess builds the house. So,


you know, you have your your house that


is built and then inside of it, you


know, you have a ball that is bouncing.


So, I don't know if y'all remember


like a video game or something, I think


from like the 80s called I believe it


was Pong. and it was just this little


ball that just, you know, went back and


forth and you'd have to move this little


thing to try to, you know, catch it and


not let it hit the ground. So, if you


want to kind of think of price like


that. So, you know, it's going to come


down, hit the, you know, the bottom


floor and then could come up,


hit the ceiling. So, those are pretty


thick walls that it sometimes have has a


hard time breaking past. And then of


course the one hour is kind of like a a


shelf on a wall. So it's still going to


have some resistance. It could the ball


could still come up, bounce off of it,


you know, come back up, bounce off of


it, but it's not as sturdy. So price


could just push right past it. And then


if you want to think of the 15 minute,


you know, it it still will hold


some weight, but you know, it's more


like a chair inside the house. So, you


know, you might price may trip over it,


you know, and kind of hang around, sit


down in the chair,


you know, kind of accumulate like it


kind of did back here. And then


eventually the ball is just going to go


right past the chair to one of these


other areas that kind of hold a lot more


weight.


So initially I'm going to put my takerit


up here


and then same thing I would set an alert


before my takerit. That way, if I'm not


watching it and I'm off doing other


things, if my alert goes off, I can then


pull up my chart and adjust at that


point if I need to or want to,


which I will usually always or not


usually, I will always move my stop loss


up uh to minimum break even. I'll


usually continue and just move it into


profit fairly quickly.


Okay, so we have our stop loss down


here, previous low.


We have our take profit. So, right now,


this is set at a 1 to8.


And don't feel like you have to always


do that. You'll kind of just play around


with it. And you know even a one one is


great. There is nothing wrong with that.


Okay. So we're going to go ahead and


play this.


Okay. So we came up. You would have hit


take profit if you would have had it


at the 15minute area.


And I'm going to wait for it to move


past there.


That might have been a news candle.


Okay, so once let's see where is my one


to one.


So once price is about at a one one


that's when I will start moving my


takeprofit or my stop loss up.


So we're going to move our stop loss to


break even


which


I usually move my stop loss up


with fractals.


So that's a good place. We're at a


fractal.


Of course, I would have waited until


that calmed down. It definitely looks


like news right there.


Okay. So, depending on if this was news,


I of course would not have moved it up


during that news event. Um, I would have


either tried to move it up before the


news hit to at least break even. That


way, in case it did do this crazy, at


least I'm out at break even. Um, if it


was not news, then, you know, we may


have already moved our stop loss up. It


may have still been down here. If it was


down here still, you would have been


safe. You can kind of see when I put


that crosshair. I don't know. we were


somewhere down in that area below that


fractal,


we would have still been safe. So,


I'm going to go ahead and just continue


to play this so we can kind of see


if it broke through. Okay, so it went


through our 1 hour.


might come back and get a retest.


So depending on how long you are wanting


to scalp, let's say we got in around


6:20.


Depending on when we would have moved


our stop loss up, we would have gotten


out at either 8:30.


If we would had not moved our stop loss


up yet


and we had our takerit right here, we


would have hit it at 855.


If you would have,


you know, went ahead and after this


candle calmed down and then moved up to


this fractal


and at the same time moved your stop


loss up,


you would still be in it. And of course,


we'll go over this in some future


training videos, but you know, moving


our stop loss up, you know, kind of see


would have gotten stopped out right


here.


Okay. So, I'm going to go ahead and


move this to


present.


So, um just that kind of gives you an


idea of


you know where I look for with support


and resistance. Uh fair value gaps if


there's any the W's the M of course the


MS would be a downtrend


and higher highs higher lows break of


structure. So I can


let me find.


Okay. So


we can go ahead and type this out.


Okay. Okay. So, we'll do a confluence


list.


Okay. So,


do W


forming


value gap.


Higher high.


Oh, what' you say in this uptrend?


Higher low.


Price rejected.


Support area.


9 EMA


crossing


21 EMA.


I think that is all of them.


Trying to think just to make sure I


didn't forget any.


Okay, so W or M formation fair value


gap.


Let's go ahead and


call this a


bullish fair value gap.


is filled which means it got tapped into


or price went inside it.


We see the higher high the higher low


price rejected


our support area


and our


9 EMA crossed our 21 EMA.


Okay. So now we have a list of


confluences that you can look at.


There are trades that I take that I


don't wait for every confluence.


You know, my risk tolerance is


probably a lot more than yours might be,


especially if you're just beginning. Um,


you know, if you want to wait until you


see this perfect setup, then that's


amazing. Go right ahead and do that.


That way, you know that it is you're


following all of your rules and if price


goes the way you want, amazing. If it


stops you out, it'll at least help you


know that


it was just the market wasn't anything


that you did. You followed your rules.


Everything was telling you that we were


going going to, you know, continue up in


an uptrend and


that just happens. So, by practicing in


a demo account and getting comfortable


with seeing everything,


you know, maybe setting your alerts,


um,


you know, and just kind of watching it,


then you'll kind of be able to see them


maybe a little bit quicker and just get


more comfortable with the confluences


And of course, like I said, if you get


stopped out, don't worry about it. Um


because you followed your rules. So,


let's see. We'll get that


on the list. And so, that is pretty much


the steps that I look for whenever I'm,


you know, kind of prepping to get into a


trade. Um,


and


it's just kind of as simple as that. Um,


it may seem a little confusing right


now, but I promise the more you practice


and play with it, you know, even if you


just kind of shrink this down, you know,


your eyes will just kind of get used to


seeing this little


ping or ponged, whatever that game was


called. Uh, you'll just kind of see it


bouncing, you know, up and down, up and


down.


And you know, we just learn


the higher time frame, the bias. Um,


you know, I'll go ahead and show you. If


we were to jump on the daily time frame,


we can clearly see


that we are in an uptrend.


And of course, each one of these


candles, since we're on the daily time


frame,


is 24 hours worth of data. So, this


candle is going to bounce. It's going to


fluctuate quite a bit in that 24-hour


time frame. So


by the time we jump down to our lower


time frames to kind of refine our entry,


you will see that


we can get into, you know, many trades


within


this 24hour period. So let's see from


So here's the 13th


if you follow. Well, price looked like


crap right there. So, believe that was


Yep. yesterday. That was Sunday.


So,


on the 14th,


let's see. And of course, we're still on


today's candle, but you know, you can


see how much movement


there was today,


you know, and we are still on this


candle. So, we might come up, break this


previous all-time high, and continue up


or it may kind of get to this area and


and do kind of the same thing. you know,


it may kind of bounce up and down for a


little bit.


And if you can see,


even on the daily time frame,


we have a really pretty


W.


So, price could


continue up. already broke that 4hour


top resistance.


All righty. Well, um so yeah, just


rewatch that video a few times and pull


up your own chart and just kind of mark


off the areas. If you want to go back to


that same chart and mark off those same


areas, go back to that same date I did.


If you're in Trading View, of course,


they have the replay


mode where you can kind of go back to


that date and get all of the most recent


candles,


you know, out of your view if you choose


to. Um, and then if not, just get into


the the live market on a demo account


and just practice over and over and over


and over and over. Um, demo account, you


can have as many as you want. So, if you


take some trades and


blow past it and lose it, that's okay.


um you know just start another one and


just keep practicing and it'll just kind


of become almost like second nature.


You'll just as soon as you open up a


chart and get on those time frames your


eyes will just see those areas and you


know they they will vary of course for


you know everybody.


what I see is an area maybe off a few


pips from the area, you know, where you


see or where you place your line. And


and that's okay. I mean, it is, you


know, let me


do want to show you one more thing if it


might help you.


Instead of using lines,


let's see. Let's go back to this date.


kind of get back to where we were.


So, if you, you know, and don't second


guess it too much, but, you know, if you


see this and you're like, "Oh, you know,


should I bring it down here? Does it


need to go up here? Where do I need to


go?" And and it starts just kind of


stressing you out. Um, you can also grab


the same little rectangle box


and you can mark out, you know, mark off


this area. If you do that, I would do it


a different color so you know it's not a


fair value gap.


And that way you just know that it's a,


you know, a marked off zone.


I just personally don't like it because


it it just puts a lot of different


things on my screen. But if it helps you


at first, you know, instead of just


doing this one singular line, then do


what you need to do. There's nothing


wrong with that. Um,


and you know, like I said, just just


keep practicing and it will get, you


know, a little bit easier and you'll


kind of create that muscle memory of


just looking at the chart, seeing those


areas of hesitation, of course, marking


off fair value gaps. if you want to


incorporate that and your eyes will


start seeing those higher highs, higher


lows, you know, lower highs, lower lows,


all of that. Uh the M's, W's, you know,


just once you just do it repetitively,


you will just see those a lot easier.


But but don't worry if you, you know, if


it takes you a little bit, and that's


completely normal. Um, I've been doing


this strategy for a long time, so it is


kind of second nature to me, but but I


do remember how it was at first, and it


was just like a foreign language. So,


um, don't rush. Go at your own pace,


what somebody else is doing on your


left, you know, versus what somebody's


doing on your right. Don't compare. Um,


and you know, just go at your own pace.


Practice as much as you can or you need


to before you feel like you need to go


to that next step of whether it be


getting a challenge account, starting a


live account, you know, just go at your


own pace. And I'm going to do another


video of, you know, just kind of


different things that you can do to


eliminate some of the stress and


probably more so anxiety that can come


with trading on the lower time frames


and different tricks that you can do to


help eliminate that. Uh but you know the


main thing especially if you see a lot


of chat in the circle you know people


taking trades and hitting a one to one


one to eight I don't know whatever um


don't worry about getting FOMO you know


don't the fear of missing out um I don't


know if you want to maybe think of


Romo instead


relief of missing out cuz they may have


gotten stopped out. You never know. So,


if it doesn't align with your rules,


then don't take the trade and do what


you need to do to keep yourself


as calm as you can while you're trading


on the lower time frames. Uh, but like I


said, I'll kind of do another video and


just go over some things that have


helped me through my journey of trading


on the lower time frames to keep me


calm, which is what what you want to be.


You need to be calm. Um, the charts can


be volatile, but you don't need to be.


So, um, okay. Well, go on and practice


everything on here. Watch the video as


much as you need to. If you have any


questions, let me know in the chat and I


will see you on the next video. Okay,


bye.$video_02_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_02_summary$This lesson gives you the roadmap for the course and explains how to approach the material in order. Shea walks through how the strategy is built, what to focus on first, and how to use the later lessons as a step-by-step system instead of random isolated tips.$video_02_summary$
      ELSE summary
    END
WHERE sort_order = 2
  AND title = $title_02$Course Overview$title_02$;

-- Backfill watch-page content for lesson 3: The Day Trader's Mindset
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_03_transcript$I don't know what it did, but okay. So,


today I just kind of want to almost go


back to basics. I, you know, I know that


we always talk about being repetitive


and building that muscle and doing the


same thing over and over again till it's


kind of second nature. Uh but I want to


you know just kind of bring back if


you're feeling overwhelmed or you know


little lack of confidence or anything


like that. I just want this call to kind


of


almost uh bring back and reignite some


of that the confidence uh with


confluences. So, um, you know, if you


have noticed sometimes when you kind of


venture away or me at least anyways, if


I almost enforcing a trade and kind of


get away from my


my rules or my list of confluences, then


a lot of times that trade might not go


my way. So,


um, stick with your confluences. Of


course, mine are the support and


resistance, uh, retest or bounce,


whatever you want to call it. Um, W or


an M, EMA cross, break of structure,


higher high, higher low, of course, in a


buy, lower high, lower low, and a sell.


Um, a lot of those I will


always


have before I get into a trade. Um, and


I will not venture if I'm ever in a


sale. A lot of y'all already know this,


especially on NAS or gold.


I will almost want every single one of


those. Uh because I'm I just always


think of the big picture and I always


feel like those two are always going up.


Um you know, especially the higher time


frame bias. So, you know, I always have


that in the back of my head. Even if I


do get in a sale, I will set more


alerts. I think because I just always


know that it might be just a pullback


maybe on the daily and it's probably a


little more short-lived than say a buy.


So, um you know, just make sure that you


have your confluences.


I know a lot of you already do this, but


put them on your chart, write them down


somewhere, check them off. Um, and do


not get into a trade until you can have


them all checked off or at least I would


say maybe


three, a minimum two confluences.


If you do maybe a rule of three, that's


even better. And then that way if you


know a trade does not go your way, it


should help a little bit or at least it


will over time of not like knocking down


your confidence and you know getting you


to think that you don't know what you're


doing all of that stuff. So you know if


you stick to your rules then


you know just know that just the market


was marketing. So, I did mark off some


trades


and I just kind of wanted to


go over them with you. And they're not


necessarily trades that I took. I just


kind of went back and looked at which


ones met the, you know, criteria for my


confluences


and to show that, you know, a lot of


them got at least a one one. Some of


them even got a little bit more. So, of


course, this one right here,


you can see that we had a rejection off


this, you know, of course, this one was


a caution area. Uh, we had a lower high.


We had an M. Not a beautiful M, but it's


there.


Let's see. Go ahead and mark this off.


Yeah. CANC and M.


And then of course we had our EMAs cross


right here. We had to break a structure.


So whenever this candle came down broke


this structure. So you know and even


setting it up here above the you know


previous high at this caution area or


the resistance area it would have gotten


a one one.


This one of course would have gotten a


whole lot more but you know if you like


say were to get in this trade you know


you hit a one one great get out move


your stop loss to break even kind of


whatever your rule is once you are in a


trade but you know getting a one to one


and then we had this little pullback.


So, you know, you may have seen this


seeing that lower or that higher low


even a little bit of a higher high,


you know, that's where if you start


seeing that and you start maybe


secondguing, oh no, I see a W forming.


Um, and I did this on the five minute


just to


>> just a little bit


>> cut out some of the the noise in it. But


um you know if you did see that you may


have um you know started questioning it.


So if you maybe did set more than a one


one then you know either closed out of


it or you know whatever you kind of


decide at that point but but you at


least would have gotten a one one.


And then of course right here,


same thing. We had EMA cross


a higher high a W. Same with this W.


It's


not real pretty, but a break of


structure


rejection off this area. So it would


have got a one to one.


And of course, we had this bearish fair


value gap from back here.


And you know, price came up, broke


through it, came back down, filled


orders, turning it into an inverse fair


value gap, and then price started coming


up. And of course


on the 15minute


there was another


bullish fair value gap. Let's see if I


can get back to that now.


Where did that go?


There we go.


I hate that whenever my screen


gets off like that.


Okay, so we ended up having


a bullish fair value gap and you can see


the price


came down


really like kind of stayed in this area


was filling those orders had a little


bit of range consolidation


and then if you wait for this break of


structure


and you rejection off of the fair value


gap because it was respected. The EMAs


crossed


break of structure. You can see we have


a W right there


and then set stop loss below this


previous low


and you would have gotten one one.


And then of course, same thing right


here, except this one.


It's always, I think, harder for me to


find ones that did not work out that fit


all of like the criteria of my


confluences. But, um, so right here, you


can kind of see except that's supposed


to say


lower high.


So, of course, you can see as far if


we're looking for a buy, you know, we


had a lower high


and then


an EM. I mean, you can kind of see an M


right here if you're kind of marking


those off.


So, we had


an M


Let's see.


Trying to think. I saw that 21 EMA


re Oh, right here. Yeah. Okay. So like


this one, if it was a continuation


and you know you were looking, you see


this rejection off or the retest of the


21 EMA and then you know so if you're


looking okay maybe I wanted to get into


this this buy. We had a pullback and you


know maybe I can get in on the rest of


it.


You know we had a little W right here.


So, it's kind of giving all the signs


of, you know, a W pull back into the 21


EMA break of structure, higher high, you


know, even had a higher high here. Uh,


but you can see that, you know, if we


would have set it at the break of


structure for a one to one, we didn't


get that. It immediately came down and


would have stopped you out. So, you


know, can y'all see like any reason


why you think that would not have worked


out? I mean, I know there's maybe like a


couple of things that I would


maybe say like of course in hindsight of


why like h maybe I could have waited on


you know that or this and maybe that's


why it didn't work out. Um, but you


know, do y'all see anything that


in hindsight maybe would have made you


think


that you can see why that would have


stopped you out?


>> Maybe if you look to the left, that was


there um a resistance back


>> like Yeah, up here somewhere.


>> Right to the left.


>> Yeah. And see, and that's kind of one


thing that I would also think is, you


know, maybe like I mean, we did have a


this 4hour resistance and I know this


may not have been what it was back, you


know, on this date, but just kind of


looking off of this, um, you know, I


think the same thing. you know, there


could have been a resistance area up


here, even a area of some kind of


hesitation or caution. And of course, if


we just kind of based it off of what we


see right here in this 4hour area, you


know, where we came up, we didn't really


have a good retest down into that 4hour


resistance. And also since we were


looking for buys,


um, you know, right here, you can see we


still have these higher lows. And then


right here, we almost had like a little


change of character cuz we ended up


getting a lower low and we never got a a


confirmed higher low after that. So, you


know, kind of looking back,


I would have seen that like I maybe


should have hesitated whenever it


created this lower low right here, even


though it was just a retest into the 21,


but you know, maybe I should have waited


until, you know,


I saw a higher high or something and,


you know, kind of determine it from


there. Um, you know, even if I would


have saw this one right here and, you


know, would have waited and set that box


keeps getting in my way.


If I would have saw this higher low and


then of course set right here, then I


never would have gotten triggered in.


So, it would have been would have been


fine.


So, of course, you know, other than


that, it did kind of meet a lot of my


confluences. So, sometimes they just


don't go your way. Um, you know, and of


course, the more confluences you wait


for. Sometimes that can even save you


from getting into a bad trade. Sometimes


it won't. uh but you know at least it


won't knock down your confidence if it


doesn't. And then of course here's


another one uh that you know would have


worked out W EMA cross higher higher low


break of structure rejection off this


4hour um resistance area and you would


have gotten a one one. So, uh, the


reason why I was kind of wanting to show


you all that, let me get back up here,


is because I was wanting to talk to


y'all about just the importance of back


testing and forward testing. Um, I know


in the


uh circle


You know, I definitely see a lot of


y'all doing


back testing and, you know, even a


little bit of forward testing, but um


who was it? Laura. whenever I seen her


post, um, it just almost like confirmed


to me that I wanted to go over this with


y'all again because what she ended up


doing with gold,


I think like last week, just to kind of


find out, you know, what time she was


wanting to trade and what trades she


would have been able to catch during


that time. Um, that's what I think all


of y'all need to be doing. Um, you know,


of course, back testing, I do think it


is important to do back testing, but


just as important, I think it's, you


know, also good to do forward testing.


So, you know, of course, back testing


gives you the data, uh, not the, of


course, dopamine of being live and


getting into it at that moment. um you


know it builds a statistical


relationship with your pair. So,


whatever pair you want to choose or if


you're still kind of deciding what pair


you want to go with, uh, you can kind of


see, okay, statistically during this


time of day,


it, you know, I would have gotten,


you know, three one to ones or something


like that.


You know, during this time of day, it


doesn't move that much. It kind of stays


consolidated. It's really slow. So, but


it's the, you know, time of day that I


want to be trading. So, maybe I won't


stick with this trade. Um, I kind of


thought that with gold last month. You


know, I always trade NAS because I like


what it does during the hours that I


want to be trading. And so whenever I


switched over to gold, it kind of took


me a little bit to, you know, go back


and see what time of day it moves. And


luckily it moved a little bit during the


time that I wanted to be trading, but


you know, mostly gold does really well


during like Asian session. And so there


was a lot of moves I realized I was


missing because I was sleeping and you


know so I think that's where I kind of


you know well gold if it's doing


something during the time of day I want


to trade fine I'll get in a trade if not


that's whenever I kind of will pop over


to NAS or whatever else I'm looking at.


Um so you know um


of course if it wouldn't have worked out


in the past why expect it to work out


into the future? So, if you are kind of


back testing and you see, okay, if I


would have set this trade at 7:00 a.m.


and


you know, maybe all of your confluences


weren't there and you marked it off, put


your box up and it didn't work out, then


of course whenever you're trading in the


live market, you know, or up to date,


then, you know, just know that I


probably shouldn't only use one or two


confluences during this time because it


never worked out whenever I was back


testing it. and and then of course


forward testing. Uh so I think back


testing is really good for learning your


pair, learning what time of day it moves


best. Uh if that works for you or not


roughly, you know, how much


risk-to-reward you would have gotten,


how many trades throughout the week, you


know, kind of your win loss ratio. Um I


think that's great for back testing. uh


forward testing I think is great. Uh you


know if you are watching the chart say


right now what it's doing and you you


know maybe


um like don't want to set a trade but


you want to


you know just kind of see what it would


have done. I know Jill does this quite a


bit and I always think it's a great idea


to do that. um you know it's like well


let me box it off and go back and see


you know if I would have hit take profit


if it would have hit my stop loss but


that trade you know that you were


watching maybe fit all of your


confluences so you know it's a great way


to build your confidence you know so


only mark off trades that align with


100% your rules. Uh, whatever your


confluences are, only mark off ones that


match that. Don't veer off any from


that. And then, you know, go back and


look at it. So, you know, even and of


course do it in like a well, I guess it


doesn't matter if you do it in a paper,


you know, or your real account if you


just box it off. it. If you want, you


can even do it in a practice account and


actually get into it if you want.


But you just know it's in a demo, so you


know, it's not going against you


necessarily. Um, but you know, it will


build that muscle memory and the trust


in your execution. So if you you know


say take


I don't know maybe two days a week and


you only box off trades that you would


have taken and you know go back and look


at them and you know you kind of see


okay so if I stick with a minimum of


three confluences


mark them off you know or get into the


trade there's you know 70% of the time


the trade went my way and I at least got


a one to one over time. You know, of


course, that will build that muscle


memory to where, you know, you just look


at the charts and you will just in a


second or two see all of your


confluences. you know, I see a W, I see


the EMA cross, break a structure,


higher, high, and it will just build


that trust to where you trust yourself


to know that if I stick with my rules,


it usually went my way. And, you know,


and if it doesn't, that's fine. We all


know you're not going to win every


trade.


Sometimes the market just markets, it


just does its own thing. But with all


that said, you still trust yourself. You


still trust your confluences.


Um, you know, and you just kind of start


building that muscle memory. So, even if


you decide you don't want to trade your,


you know, prop account or your live


account,


still, you know, mark them off and go


back and look and see what you would


have gotten. And you know whenever you


are forward testing if you you know


maybe go back and see that they would


have all hit your one one you know don't


don't go back and view it as a bad


thing.


Don't kick yourself that you


got the one one but you didn't set it in


your live account. Um, you know, just


kind of view it as like kind of building


that trust and you know that it was a


good thing that you saw the correct


thing and made the trade and next time


whenever you're sitting in the live


market then you know that you can trust


yourself and your confluences.


So um you know maybe sometime this week


um you know do 10 forward tested trades


uh and journal each one you know what


confluences whether it's you know you


just put it on your chart or do kind of


like I do with this little call out tool


you know just on each one just kind of


write on there you know these were the


confluences I waited for and I got a one


one. And then, you know, go back and


look at those 10 trades uh that you


marked off by doing the forward testing


and just kind of see what your


statistics are for that week or the two


days or however long you want to ch, you


know, do that. And then of course, a


bonus if you want to go back and do 10


back testing ones. Um, you know,


especially if you're maybe kind of


trying to


decide if you want to switch pairs or


add another pair. Um, you know, go back


and look at that just to learn how they


move, what time they move, and all of


that and to kind of build that trust


with that pair and, you know, of course,


that muscle memory.


Um, so let me Do y'all have any


questions regarding


any of that stuff?


Thought I did see a question. Let's see.


Is it okay to have fractals on only one


side like higher highs but not higher


lows? It is. Um, and let me go


and kind of


find an example. So I will say


for me if I'm say looking for a


you know


say a sale in this case um if I'm


looking for a sell I do it is nice if I


see a lower low but I want to more so


see a higher high if I'm in like a sale.


If I'm in a buy, I would prefer to see a


lower low. And that's only because I


want to see that price, you know, did


try to come back up. Buyers tried to


come up and, you know, take over, but


they failed to, you know, take over.


Buyers or sellers came back in and, you


know, so it gave us that lower high. So


that just kind of confirms to me that,


you know, okay, we are not going, you


know, or we failed to go higher, so you


know, we're going back down. Um, and


then of course, you know, the same with


the lower lows. if you're looking for a


buy. Um it just it kind of tells me the


the same thing just that


um sellers,


you know, failed to take over. buyers


are still in control and, you know,


we're possibly going back up, you know,


but um so yeah, you don't necessarily


have to have them on both sides, but it


is better if you do. It's just not a


rule of mine. Um, you know, to have both


of them. But I do want to have at least


a higher low in a buy or a lower high in


a sell.


Okay. So, we're we're all good on that.


And then I also


wanted y'all to write this down


somewhere. Keep it by your computer.


Always remember it. uh that mastery


doesn't come from doing it once. It


comes from repeating the right things


until they're second nature. Back test


it, forward test it, and let your muscle


your butterfly muscle memory take over


and shove doubt, fear, and anxiety out.


So um you know just just know every


trade's not going to go your way but


confluences


definitely can build confidence


if you you know


back test them forward test them that


always helps as well of course.


Okay. So, if we don't have any questions


regarding any of this, then I'm going to


um


hop over


and hold on. Let me see. Amber, where


you want me to look at this?


>> Yes, if that's okay.


>> Okay. No, you're fine. Let me I just got


it pulled up.


Okay. So,


let's see.


Okay. So, what were you wanting me to


just kind of double check your entry?


>> Yes. I'm just curious if I if that is a


break of structure there. Um, mostly I


think I see that.


>> Okay. So,


>> it's a buy, correct?


>> Yes, I saw the W and the EMA cross and


then I thought that was a break of


structure there and I just wondering if


this is just an example of how it just


didn't work out.


>> Yeah. So, the break of structure in this


one, um, if it's that kind of big W that


you saw,


um,


see up there where maybe


I can't tell if maybe that's an or like


your resistance line.


>> Yes.


>> Like the very top. Yeah. So that's where


I would maybe, you know, if it's that


big W, I would watch for that break


structure at like the tip. And I don't


know if you can can you see my cursor on


here?


>> Yeah, I can.


>> Okay. So like right here


if you're seeing like if this is the big


W that you were seeing.


>> I was using the little a little W


towards the


>> Oh, right here.


>> Yes.


>> Okay.


>> Okay. So let me see. Yeah. So


I don't know. I think with this one and


I do see that little W and then of


course you know the break structure, the


EMA cross, the higher low,


but this right here is what I maybe


would have been a little bit cautious


about.


>> Okay,


>> just with it being below,


you know, and pretty close to that


resistance line. Um, you know, I would


have either like if this would have


triggered you in right here, I would


have maybe put an alert right here just


to kind of let me know, hey, just be


aware of it and then of course either


moved like stop loss up to break even or


profit and then start watching what it


did right in here. And then of course


once I started seeing like some of these


signs, you know, maybe EMA cross, but


seeing it reject off this line and then


starting to kind of give us a little bit


of signs that we could be reversing, I


would kind of have watched it right in


here to where, you know, maybe you at


least get out at break even or maybe a


little bit in profit depending on where


you moved it. Um, but I would have


watched it around that. So other than it


being near this resistance area,


I think that's, you know, that's fine


what you did right here.


>> Okay, that's helpful. Thank you.


>> Okay, you're welcome. And I was also


going to tell you um if you look up I


don't know what fractals you have but if


you don't like them being that big um


>> please help with that. If you go into


your indicators and look up Rachel T,


>> okay,


>> fractals, they're smaller because I did


the same thing whenever I got my uh


Trading View pulled up and I was just


like, why are my fractals so dang big?


But if you look up the Rachel T in


Trading View, it'll make them a lot


smaller.


>> Yes, thank you. I've just been dealing


with it, but I Yes, I'm going to change


them. Thank you.


You're welcome.


Okay, so now I'm going to hop over and


um so I think our calls for our book


club thing is going to be on Fridays at


noon central standard time. And I'll put


all this into circle. And then I just


kind of put all of the books that,


you know, I thought maybe would, you


know, could help us if we started


reading them. All of the recommendations


that y'all put into circle. I just kind


of threw them all in here. And then I'm


just going to kind of spin this wheel


and we will see which one we start with.


Okay. I was like, what if what do we do


if it's in the middle? So, okay. So, the


millionaire success habits. I'm going to


write that down


if I can find my post-it note.


So, I will put this


in circle and then I'll put the author.


I'll maybe um


take a picture of it.


Actually, hold on just a second. I've


got it right here.


So, I will of course put this in circle,


but let me


Okay, so I don't know if y'all can see


that and it's probably backwards, but um


it is


by Dean


Graiosce. I probably butchered his last


name, but So, I'll take a picture of


this and I'll throw it into circle.


um that way we can all you know of


course be on the


be on the same book. But um but I will


say that I have read this book and I


loved it. Um so but of course I I'm fine


reading it again and I'm sure you can


get on um you know get like an audio


version of it. Usually I seem to always


get like a hardback of a book or


paperback just in case I ever want to


like highlight anything in there. And


then but also get um the audio version


cuz if I'm walking maybe on like my


walking pad at home and I just want to


listen to something then I'll throw the


audio book on and sometimes I can like


concentrate a little bit more cuz I


don't know something about my brain


whenever I start reading.


It's like if I ever have insomnia, all I


have to do is get a book out and it's


like I will pass out. So, it takes me a


little bit longer to read a book versus


listening to the audio book. So, you


know, if you want to whichever one you


want to do, um I know it'll well today's


Monday, so I was wanting to start this


this Friday. So,


you know, we'll hopefully a lot of you


that order it will be able to have it by


then. And, you know, I'm not sure how


far we'll get, I guess, depending on how


many days it takes to get the book in.


But,


um, but either way, we'll go ahead and


start the call Friday and maybe just


kind of figure out how we're going to do


this. Um I am thinking maybe


you know a chapter a week or at the end


of the week uh you know at least talk


about a chapter that way in case


somebody's busy and you know they don't


feel like they have to read five


chapters a week or whatever like me like


I want if I get ahead that's fine but if


not then I'll be like oh my gosh I got


to hurry and read three more chapters.


So, I think one chapter a week is kind


of a good middle ground and then we can


just kind of talk about it and talk


about whatever. So, um so yeah, that'll


be exciting. Uh it'll be the same thing.


um we will add it to the calendar the


events um so it'll be the same link but


I'll throw something in circle that way


y'all can just you know click that Zoom


call for Friday um and then we'll just


kind of see how it goes. If we see that


we need to maybe adjust the day or the


time later we can always do that. So um


so yeah that will be exciting. Um, I'm


the exact opposite. If I listen, I drift


off until Oh, man. That's so funny.


Yeah, I feel like it has to be like I


can't really have any distractions


either. I'll go through like four


chapters and be like, I was thinking


about what I was cooking for supper.


Like, I have no idea what I just read.


Okay, it's on Spotify for those that


have that. Okay, that's good to know.


So, it will be Fridays at 12:00


uh noon.


Uh Central Standard Time.


So, hopefully that'll, you know, hit


some people's lunch hours.


Okay. So, it's on Audible. Okay. So


yeah, you can either download the the


audible version if you, you know, maybe


want to do that until a book comes in if


you want to have a paperback or


hardback. Um, you know, so we can maybe


start Friday talking about it. So all


right, guys. Well, I think that's it.


So, I will throw all of that information


into circle and hopefully this kind of


helps


reignite some of your confidence if you,


you know, have kind of um been not


feeling very confident with how the the


charts have been. So, follow your


confluences and know that that you're


doing great. follow your rules and if


things don't go your way,


it's fine. It happens. So, all right,


guys. Well, y'all have a good day and I


will see you tonight at 700 p.m. Okay.


Talk to you'all later. by$video_03_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_03_summary$Shea resets the mental side of trading by bringing the focus back to repetition, patience, and confidence in your rules. The goal is to stop forcing trades, stay grounded in your confluences, and build habits you can repeat under pressure.$video_03_summary$
      ELSE summary
    END
WHERE sort_order = 3
  AND title = $title_03$The Day Trader's Mindset$title_03$;

-- Backfill watch-page content for lesson 4: Charts, Timeframes & Tools
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_04_transcript$Hey everyone. So, in this uh video, I'm


going to quickly show you just different


platforms that you can go ahead and


download. Uh and possibly even some


brokers. Uh that way you'll kind of have


your chart set up. That way you can, you


know, start kind of eventually placing


trades or just looking at the charts and


seeing how uh price moves and just kind


of getting more familiar with it. So, um


you'll want to check maybe depending on


which country you live in, each country


might have, you know, their own rules


and regulations on which brokers you can


use. So, just do your research and kind


of find out for sure who you are allowed


to use. And um I'm just going to kind of


quickly show you who I personally have


on, you know, or who I use on my


computer to either look at the charts


or, you know, markup and all that stuff.


So, um let me go ahead and share my


screen.


Okay. So, one that you'll notice that


you can use with, you know, different


brokers. Um, it kind of will integrate


whether you're wanting to just trade


forex or whether you're wanting to, you


know, maybe go into futures and, you


know, trade contracts and all that,


which we'll get into later. Uh but for


now um you can go ahead and set up a


Trading View account. So if you just go


to tradingview.com


and then come over here to get started


and it'll bring up some different plans


and I just had this essential one and I


think it's good enough for now. So um


I've never had to upgrade. So if you


want just click on that for now you can


you know try it for 30 days kind of see


what you think and so just go through


all of those steps get you an account


created and then you will open up


over here on trading view


and then down here on the bottom under


trading panel you'll then find different


brokers that you can connect through.


So, whoever you decide you want to end


up using after you kind of research


different brokers and decide for you


where you live, what you're wanting to


trade the best broker. So, um, for me,


for, um, my futures account, I've been


using Trade Station. So, you can set up


an account with them if you want to if


you want to kind of look into trading


futures. Um, I know some have used


Oanda.


I believe the only thing with the you


can trade forex but if you're wanting to


trade say crypto indices metals like


gold silver things like that


you will not be able to trade that with


so you'll want to kind of research some


different brokers


that allow you to trade that you know if


you aren't wanting to use um a futures


account like Trade Station. There's also


Trade Ovate


um which is right here. So,


like I said, I know there's quite a few


people that have used Weeble, uh


Coinbase. So, just kind of depending on


where you live and then you can kind of


research


from there. So, and then go ahead and


set up an account with them as well. So,


for now,


I'll just go ahead and click on this


paper, which is a demo account. Um, and


that's another thing. Once you do kind


of find which platform you want to use,


which broker you want to use, go ahead


and set up a demo account, which is


essentially Monopoly money. So, um I


know there's also Trade Locker, which


in the past is who I've always used. I


love them cuz I was able to trade forex


and all of the other the crypto, metals,


indices. Uh but the broker, I'm unable


to use them anymore. So, I haven't


really researched any other brokers that


integrate with Trade Locker. So,


until until then, and I'll kind of


update later if I find one that I really


like. But for now, just to get you


familiar with looking at the charts and


all of that, you can go ahead and just


get with the um get a Trading View


account and


and it'll it'll be good for now. Um


okay, so


you want to go ahead and create a demo


account, which is you you know, you


can't go wrong with a demo account.


You'll want to practice in there before


you put any of your real money into an


account. You want to make sure that


you're really familiar with the chart,


with a strategy, with a pair, whichever


one you choose, um before you, you know,


start putting your your own money into


it. So, um, once you have your demo


account set up and you have your chart


pulled up, then from there it'll


probably look very foreign, especially


if you've never traded before. But I


promise there's


a lot on the screen that you don't need


to worry about and


and it'll get a whole lot easier. I


promise. Um, so to, you know, kind of


quickly run down,


you know, how to maybe set up whichever


pairs you choose to trade. Um, while


you're in a demo account,


trade


whichever pair you want and really get


to kind of know


your pair, whether it's through back


testing, which we can, you know, we'll


kind of cover all that later. But um but


for now, just while you're kind of


getting familiar with it and trying to


decide which pair you even want to kind


of stick with and really get to know,


then just download a few of them and


just kind of play around with them. Um


so I'll show you how to add a symbol. So


you just go up to this little plus sign


up here and then for


this section right here is my futures.


So, if you choose to have a futurist


account um you know you can just click


on this future


and then uh once you're on that futures


tab then you can just type in you know


whatever one if there's a particular one


you're looking for. So, for instance,


NASDAQ, you can do a mini version, a


micro, or just the


the regular size one. Um,


let's see.


I'm going to take this out of the search


bar. And then if you aren't sure which


one you want to add, then you can just


kind of go through. There's crude oil,


gold, uh, Bitcoin, silver, platinum,


copper.


There's a ton of them. So, whenever you


do find one that you like, see, let's go


ahead and add this one just since I


don't already have it. You just click


this little plus sign over here. So,


it's add to watch list. And then once


you do that, then you'll find it over


here on your little drop- down list. So


you can go ahead and add as many as you


want. If you want to trade, you know,


forex pairs, then just do the same way.


You just go to Forex and then click on


whichever one you want. So with the


forex uh what what these kind of


abbreviations mean is you're basically


trading the US dollar versus the this


one for instance is the Japanese yen. So


you're you're kind of just looking at a


chart and determining if you think the


US dollar is stronger or weaker than the


Japanese yen. So of course we'll kind of


dive into all of that a little bit more.


Uh but you know if you're kind of just


curious what those abbreviations mean.


So, and then of course I just have mine


categorized with Forex and then futures.


So,


for now,


we'll just go ahead and pull up a NASDAQ


chart. So, I just want to kind of


quickly show you a quick rundown of just


the price movement, what it is, what


you're looking at, and


just kind of get you a give you a basic


idea. So, pretty much what you're


looking at is the NASDAQ chart. Let me


get on a little bit of a higher time


frame.


Just a second. I'm going to take


this off of


my chart just to make it kind of a blank


canvas.


Okay. So, whenever you're looking at


your chart, especially if it's the first


time you've looked at one, basically


what these candles, these bars are, I


keep mine green and red, but they're


called candles. So, on my chart, I have


it to where the green represents


prices going up. Uh, my red candles


represent prices going down. So, um,


luckily


with what we do, we can make money


regardless if the, you know, whatever


you're trading if price is going up or


price is going down. So, it just


depends on if we are in a buy and price


goes up, then we will make money. If


price is going down and we happen to be


in a sell then we can make money going


down as well. So um you can kind of see


how price or how these candles are going


in an upward trend. So that just is


showing that you know price is going up


the the cost of NASDAQ you know. So


right now it is at 23,000.


So just kind of give you a basic idea of


the candles, each one of these candles


represents a time frame. So depending on


which chart you're on, for instance,


right now we are on the 4hour chart. So


each one of these candles


represents


4 hours.


So it takes 4 hours of price data to


make up one of these candles. So


give you a pretty good idea of how long


this has been in a little uptrend.


Let's see. Since


5:00 p.m. on


June 22nd. So, um, kind of give you a


pretty good idea. You can switch to the


daily time frame if you want more of a


broader view. But


just remember, whichever time frame you


are on up here represents


that candle. So on this, we're on the


daily time frame. Each one of these


candles represents


one full days worth of data. So you can


go up here


and if you click on this little


dropdown, you can star whichever time


frames you want to look at. So I always


have my daily,


my daily, my 4hour, 1 hour, 15minut,


5 minute, and 1 minute. I have those as


my favorites just so it'll keep it up


here on the bar and


make it just easier for me to access.


Um, so I'm going to


put a little side by side


just to give you an idea.


Let's see. This one I'm going to put on


one minute. So, I usually trade the one


minute time frame. Um, which is of


course what would be considered


scalping. So, we kind of quickly went


over that in the first video on


scalping, what it meant, which time


frames, and I just want to show you


kind of a sidebyside comparison. So on


this chart over here, I have my one


minute time frame. So each one of these


candles is represents one minute of


data. So basically if you want to think


of it as um the candles are like the


heartbeat of the market. So tick by tick


it is showing you what price is doing


every minute. So


this one is 1 minute. This side over


here is 1 hour. So you can see


right now


we have 49 minutes left of this hour


candle right here. So


while this is not moving very much at


all, you can see over here on this one


minute time frame,


lots of up and down movement. So


whenever I'm looking at a chart


in this 1hour time frame,


I might begin, you know, get in and out


of a scalp multiple times. So there will


be some pullbacks.


So you can see, let's see, 21. So if we


go back to


right here, this green candle


was


the beginning of this hourly candle. So


at


let's see, let's find that again. So, at


2:00


my time right here, this green candle


was the beginning of this 1 hour candle.


So, you can see how much it has gone up


and down, up and down. And this one is


just a itty bitty candle for, you know,


for the moment. So, you know, just to


kind of give you a


a pretty good idea on the lower time


frames versus the higher time frame. So,


the higher time frame is very good to


view for


kind of the overall trend. So you can


see if I switch this chart over here to


the daily time frame,


we are in an uptrend.


And you can see these daily candles are


going up.


And then over here,


let me shrink this down a little bit.


I'll get to a little bit of a higher


time frame so we can shrink it down a


little bit more.


So now we're on the 15minut time frame


and we can go back to


around July 7th around two days ago. So,


so this right here is 2 days worth of


data on the 15minute time frame. And


then of course you can see over here


on the 7th which is this red candle


right here


just that little bitty movement. So just


to give you, you know, kind of a visual


side by side visual of the difference


between looking at the lower time frames


versus looking at the higher time


frames. So


in scalping


we will be trading the micro movements


of the higher time frame candle. So, so


just kind of give you, you know, a quick


rundown on


price movement, what it looks like, what


the, you know, what the chart looks


like. So if you, you know, want to maybe


kind of think of it as, you know, this


the one minute time frame, which is what


I scalp, even the five minute, no matter


which one you kind of land on and stick


with, whether it be the the 1 minute,


the 5 minute, the 15minut,


you can kind of view that as like a


sniper scope. So you are really zoomed


in at what price is doing in that moment


and then you know maybe say the 1 hour


time frame is maybe more of like a view


of the city. So you're above the city


looking down and you can see, you know,


not only maybe the house like you would


you're looking at with the 1 minute or


the 5 minute, you know, you're zoomed


really close and you're looking at one


particular house and then, you know,


maybe the 15minute is maybe a like an


aerial view of the neighborhood. And


then, you know, you zoom out a little


bit further, get on the 1 hour time


frame. And, you know, maybe that's an


aerial view of the city. And then, of


course, the higher time frame, say the


like this one, the daily,


you know, might be like a satellite


view. So, it just it's the same view,


same chart. You can see the price is the


same on both of these. So, you're


looking at the same information, you're


just maybe zoomed in or out


a little bit more. Um, you know,


whenever you're scalping. So, just to


um, you know, if that maybe helps you


kind of understand the time frames, you


know, just cuz we're on a different time


frame,


we're on the same chart, the same


information. So,


go ahead and get all of that set up. Uh,


get your platform, whichever one you


choose to, you know, trade on. And then


your broker. Do some research. Find out,


you know, who you can use in your


country,


whether you know, regulated,


unregulated,


if you want to do futures.


And then once you kind of do your


research and decide who you want to use


as your broker, go ahead and set up an


account with them and then go ahead and


um


set up a demo account. So once you have


your demo account set up, then in the


next video I'll go over,


you know, getting the same indicators on


your chart that I use and and then we'll


kind of get in into more detail on


actually getting your chart set up. Um,


I can even go into, you know, again


adding the different pairs that you


might want to look at. And that way your


chart is set up exactly like mine. And


you know, that way on our um our weekly


class calls,


you're looking at the same thing that


I'm looking at. So, um, let me know if


you have any questions and, um, if not,


we will, uh, kind of dive into more on


the next call. Okay, bye.

Hi everyone. Okay, so in this video I'm


going to kind of walk through the chart


and show you how to add some indicators


on your chart. Um, it's the same


indicators that I use to kind of


determine which trades I'm going to get


into and kind of help me find like the


setup and know which way uh price is


going and maybe like a shift in


momentum. So, let me go ahead and share


my screen with you.


Okay. So,


by now you should have a um your


platform set up and logged into a broker


account, you know, a demo account and


just kind of have a blank canvas. So,


let me Okay, so right now it doesn't


matter. I've just just got on the uh


hourly time frame for now, but okay. So,


um first and foremost, I'm not sure I


don't remember how the chart kind of


initially sets up just by default, but


if you want to change like your


background color, the color of your


candles, any of that stuff, I'm going to


quickly show you how to do that. So just


anywhere on your screen if you right


click and go down to settings


then you can go up here to symbol. This


is where you can change the color of


your candles. So, um, remember I just


have my buy candles, the ones going


showing me that price is going up green


and the candles that are showing me


price is going down. I have those as


red. So, you can change them to whatever


color you want. H, you can change the


wick. I mean, you can get as creative as


you want with it. Um, so that's where


you can change your candles. And then if


you want to change like the background,


you can change it, you know, to any


solid color,


you know, just whatever you want. So,


let's see. We can go black. We can go


green.


Some reason I just always like mine


white. Uh, but yeah, you can change it


whatever color you want. And then of


course click okay.


So you kind of got the background, your


candles the way you want them. And then


um so as far as the indicators um I'll


kind of go through each one and kind of


quickly give you an explanation of you


know what they are, what they're used


for, what I use them for, and kind of


what determines


how they pop up or where they pop up. So


uh first go up here to indicators.


We're going to add the EMA or this


moving average ex exponential


and then so let's see I think you can


just


yeah if you just search EMA


and then it'll pull up the moving


average exponential and then you can


just star it just to right here just add


to favorites.


Okay. And then I'm going to put that on


my screen


twice cuz I want two of them.


And then I'll exit out of there. And uh


quickly I'll just kind of um give you a


quick explanation of what they are, why


they pop up. Okay. So it's basically


just shows the direction of the price.


So um the way these are calculated is


it's it takes an average of the previous


candle. So I always use the 9 EMA and


the 21. So for instance, the 9 EMA is


calculated by the previous nine candles.


So whichever direction the previous nine


candles are, it will kind of throw this


EMA to kind of give you that moving


average. So but we're going to change


the settings. So, whenever you clicked


on those two, it should have popped it


up right over here. So, if you go right


here to settings


and then


my 9 EMA,


I just want to do it like a black color,


a dark color. Actually, I think that's


more black. Okay. So, I'm going to click


black. And then I want mine


a little bit thicker.


So, I'm going to come down here to this


thickness


and then click okay. And then same


thing, this other one that popped up, I


want to go into those settings.


And I want this to just be I kind of use


like a a gold orange color.


And then same thing, I want to make it a


little bit thicker.


And then on this input up here at the


top, I'm going to change this length to


21.


And then click okay. So you can see it


popped two of them up on the chart. The


9 EMA, which is input, length is nine. I


don't mess with any of this other stuff.


And then style, I want mine black. And


then 21. Settings.


Input length is 21. And then style is my


orange color.


Okay. So, got both of those up on my


screen. So, you can kind of see this


black one is just kind of going up based


on the previous nine candles. And then


this


kind of orange one is based off the


previous 21. And one more thing that I


want to make sure is checked on you. So


go back into settings and then on the


inputs tab, make sure down here on time


frame that it's just on chart. So you


can pick any time frame you want. if you


want it to only calculate say on the


five minute chart but I want mine on


chart that way if I move you know


between the 5 minute the 1 minute the 1


hour it'll kind of automatically


calculate for that particular time frame


that I'm on that particular chart


so I basically I don't want it to lock


into place. So, okay. So, we have the


9 and the 21 EMA. We're going to go back


up to indicators again. And then I'm


going to put the fractals. So, you can


search fractals.


I use the Rachel T. So, you can favorite


that.


And then just click on it and it'll put


it over here on your screen.


And then I don't ever do anything in


those settings on these, but if you want


to,


you can, you know, change the color. You


can


change if you, you know, want it to be a


a flag,


square, circle, whatever you want,


whatever shape you want it. Um, I've


just always used the triangles


and then kind of the same thing. You can


get as creative as you want with the


colors of them as well.


Okay.


Except I am going to


come in.


I want my


top fractal


to be green.


And then my bottom fractal,


I want it red.


I want it pretty solid.


Okay. So now we have the fractals


on our screen as well. And so with what


the fractals are um or kind of how


they're calculated I guess is it


basically is like a five candle pattern.


Um so if it you know has a pullback


and that is the lowest of the five


candles it will put a fractal to show


you that price has stopped and now we


are moving up in this you know example


same thing right here whenever price


stopped and started coming back down it


will throw a fra a top fractal up. So if


you ever see, let me find an example.


So see there's a fractal here and then


you don't see another fractal for a


while. So if you don't see a fractal, it


just means that there's a lot of


momentum. Um, so I pretty much use


fractals uh to one


show me a visualization of momentum, you


know, especially with the lower time


frames. Um, I use them to manually trail


my stop loss, which we'll get into


later. Um, and then, um, also just to


show me, you know, a potential shift in


momentum. So, you know, if I happen to,


you know, see prices coming down and


then all of a sudden I see a fractal pop


up, I know that I, you know, may need to


kind of pay attention that it could


potentially mean that we have a shift in


momentum. So,


um, okay. So, we have the EMAs, we have


the fractals, and then those are the


only two um indicators that I use, but I


do want to come over and add


some other tools


in our favorite bar. So, um


I will use a horizontal line to mark off


my support and resistance. So over here,


if you come in your trend line tools,


favorite your horizontal line, and then


it'll bring it up here in this little


menu bar.


So have horizontal line


and then


we will also add this rectangle and I'll


use it if I'm marking off a fair value


gap which we'll get into later but you


can


let's see go right here and geometric


shapes I think that's what it was


called. Yep. Geometric shapes and then


just favorite your rectangle.


So we have our rectangle and we have our


horizontal line. So we'll use, you know,


those. I'll kind of


dig a little bit deeper, kind of go into


a little bit more later on how we will


use those. Uh but for now at least


you'll just kind of have them up in your


favorites and um


just kind of make them a little bit


easier to find. And then another thing,


if you want to right here where you see


your little candles up here, if you go


on this dropdown,


the ones that I have as my favorites


are, of course, the regular candles. And


then I also have the line chart as my


favorite and the hyenashi. So, um, if


you want to go ahead and favorite those,


you can just to kind of have the same,


you know, on your chart that I do. And


then you can always switch


between these. Just makes it a little


bit quicker. So, um, and then as far as,


um, just kind of give you a


a quick rundown on, you know, higher


highs, higher lows, M's, W's, which I'll


go into a little bit more whenever I'm


going over the strategy with you. But um


I'll just kind of show you quickly why I


had you save the line chart.


So like right here


and whenever I'm looking at a trade, I


will always be looking for M's and W's


if you ever hear me say that. And I'll


um kind of explain more what they mean


and what I'm looking for. But sometimes


whenever you're looking at this candle


chart, you know, so for me,


I see this W right here


forming,


but it may be a little bit hard to kind


of train your eyes to see that


initially. So if you ever hear me say


that and you are not seeing,


you know, an M or a W that I may be


seeing, you can always switch between


your candle chart to your line chart and


it may help you, you know, kind of just


cut out a lot of the noise from the


candles, the colors, the shapes, all of


that, and just kind of bring it back


down to a basic line chart. shirt. And


you know, you can see


this W.


Let me take that off. Well, you can kind


of see this W right here.


And then, of course, you can see this M


W. So if it helps your eyes to kind of


train them initially to see the M's and


the W's, then anytime you feel like you


need to just switch over to that line


chart and and then over time whenever


you switch back to the candle chart,


you'll be able to kind of see them, you


know, a lot easier. So, um, but that's


basically the only indicators that I


have on my chart, the only tools that I


have saved as my favorites. And, um, and


then, of course, if you right click, you


can change your chart to whatever color


um, whatever color you want and just


kind of design it however you like. But


I will um maybe suggest at first to kind


of keep it pretty plain just to so you


don't get have too many distractions on


your chart and you know then you can


always kind of change change it the


later time if you want. And then over


here,


this little settings


button, if you go to, let's see where


Let me get back off here.


If you go to settings,


we are going to


right here. Okay. So, scales and lines.


If you click on this countdown


to bar close,


it's going to give you a countdown. So


right now we're on the five minute chart


or the 5 minute time frame.


So this little countdown is telling you


that it's 2 minutes until a new candle.


So I always like to have that on my


chart. Um I think other than that,


that's pretty much all that I have on


there. Um, I do like to keep it pretty


simple and um,


and just, you know, makes it kind of


less distracting for me, I guess. Um,


and then, of course, I already showed


you, I think, on the previous video, but


if you want to add your time frames,


just go to this drop down and then just


favorite right here the ones that you


want. And I think that's it. So, um,


the next video we'll kind of dive more


into, you know, the strategy and kind of


doing a quick rundown of all of that and


um,


and then get on with the training


classes. So, um, all right guys, I'll


see you in the next video. Bye.$video_04_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_04_summary$This lesson gets your trading setup ready. You'll see which platforms and brokers to consider, how to configure your charts, and how to add the indicators Shea uses to read direction, momentum, and trade quality.$video_04_summary$
      ELSE summary
    END
WHERE sort_order = 4
  AND title = $title_04$Charts, Timeframes & Tools$title_04$;

-- Backfill watch-page content for lesson 5: Understanding Market Structure
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_05_transcript$Hey everyone. So, uh, welcome to the


strategy video. In this video, I'm going


to show you how I prep for my trades


using top down analysis. So, we're going


to start with the higher time frames and


then work our way down to the lower time


frame. Um, I personally like to scalp


the 1 and 5 minute, but we'll just kind


of I'll show you different time frames.


Um, so, you know, we'll get down to the


lower ones. That way we can, you know,


find clean entries and kind of pinpoint


where exactly we want to get in. So, let


me share my screen with you.


Okay, so here we have,


let me get this out of my way.


Uh, we have a NAS trade. So, um, I kind


of wanted to find an area that was near


a support and resistance. That way, once


we get down to these lower time frames,


I can kind of, you know, show you when I


would enter. So, first thing we're going


to do is we're going to hop on to


the higher time frame. And I personally


just start with the 4our time frame. So,


what you want to do,


let me I'll go and get these off of


here. That way


you can kind of see it with my eyes.


Okay. So, what I want to look for is


areas of hesitation. So whether that be,


you know, where I see price kind of


having a hard time getting above or


getting below. Uh so that's what I want


to mark off as support and resistance.


So with the 4hour time frame, I will use


um a top and a bottom line.


And if you want to kind of think of it


as, you know, a ceiling and a floor.


So, we're going to use the horizontal


line that we put on our chart in the


previous videos.


And


you can kind of see price had a hard


time getting past here. So, you know,


you can see came down, try to come back


up, and I like to mark mine


on the candle. So, even though, you


know, we have some wicks coming up here,


I want to mark off where price stopped.


So,


we're going to put our top resistance


there.


And then for the bottom one,


we're going to do the same thing. So,


we're going to kind of see where price


had a hard time getting past.


And I tried to look at


previous day first.


and kind of see if there was an area


that price had a hard time getting past.


But sometimes you won't see that,


especially if price is really moving.


And that's okay. You can go back


further,


you know. So I kind of see this area


right here.


It kind of got touched multiple times.


Had a hard time getting past here.


finally broke through. Hard time getting


below it.


And then you can kind of see it


accumulating.


And then same thing. So, you know, if


you kind of shrink your screen up


and sometimes you can shrink it up and


go really far, you know, back. it. But


if you just shrink it up, you can kind


of see,


you know, where it kind of creates this


zone.


So once I have that on my chart and I


well, let me get down to a lower time


frame and then I'll put that on there.


Um, okay. So then after I get my 4hour


support and resistance


then I will go down to the 1 hour


and I'll do the same thing.


And just remember, you can kind of


shrink your screen down


however you need to do it to where your


eyes kind of


see an area.


So you can see if I have my


cursor right there,


you can kind of see that it's hitting


this area multiple times


all the way back. I mean, you can follow


that back to July 3rd.


You know, sometimes it broke past it and


came back down and but you can just see


it hit it multiple times.


So my 1 hour I will make a red color and


I usually will only do one area of


hesitation


for the 1 hour and for the 15 minute as


well.


Okay. So once we have that then we will


jump down to the 15minute


and we will do the same thing.


Okay. So, we'll kind of get our cursor.


If I put that there, I'm going to do


this one in orange.


Can you see how


price kind of pinged off of this


multiple times? this little area right


here.


Okay. So now that we have that,


let me


Okay, so my 4 hour


just in case you want your chart to look


like mine,


1 hour,


red,


15 A minute.


Orange.


Okay.


Actually, let's go ahead and label this


so you know what it is.


support, which is the


bottom.


And just think if something is


supporting something, it's usually


underneath holding it up.


Resistance


is the top. It's usually what you think


of something stopping it from, you know,


pushing past the top.


Okay. So, 4 hour I do a support


and a resistance


and then the 1 hour.


I think I always just call it a


resistance area, but whatever you want


to call it,


hesitation


area.


And same thing


one


resistance line


vegetation area.


Same with this one.


Okay.


So now that we have our


support and resistance from the 4 hour,


our resistance area from the 1 hour, and


our resistance area from the 15minute,


then we can


jump down to the lower time frame and


I'll kind of show you.


And sometimes you can adjust them if you


need to once you kind of get down to


these lower time frames.


But you can kind of see price just


came up and down and up and down and


kind of stayed in these little valleys.


So


and then if I see,


you know, so if you think of whenever we


were like on the 4hour time frame and I


was saying that I like to mark it off at


the candle body and not the wick.


There's uh times that the wicks are just


something like this, just a liquidity


grab. So, it's just going to shoot a


quick wake up to stop people out, the


small retail traders,


and then come right back down in its


intended direction. So, that's


personally why I just don't like marking


off the wicks.


So to give you a visualization of what


that looks like on the lower time frames


and then one step further I'll show you


what it looks like on the one minute.


So you can kind of see right here price


came up and then once it got to that 1


hour area


we just had a lot of accumulation right


here.


Okay. But for now, just so the candles


are a little bit bigger,


I will start with the 15minute


and we'll see if we get a fair value


gap,


which there's one right there, but price


already came down. So,


okay. So, I'm going to push play and


then we're just going to kind of see how


this plays out. I will pause it, let you


know what I'm looking for, and if I see


something that looks like a potentially


good trade, then we'll pause and we'll


mark it up and get into it. So, we're


going to go and push play.


Okay. So, I'm going to go ahead and


pause that just because I see a fair


value gap pop up.


So, whenever price came down to this


bottom support area,


you can see these candles had a hard


time getting past it. And of course,


just because it came up,


I don't want to immediately get into the


trade. So my 9 EMA, which is this black


one, and my 21, which is this orange


one, I want to see them cross. Um, that


is a very good confluence for me. Uh,


that price is shifting and


you know that we potentially are going


to either have a continuation or a


reversal. So, the fact that my 9 EMA is


still below the 21,


I would not want to get into a buy yet


until this crossed. So,


I see that price came above my support,


rejected. This could just be a liquidity


grab. So, we see it coming up.


the 9 EMA still below the 21. So, we'll


wait and see if it crosses. If you want


to wait until it crosses on the 15minut


time frame,


you can. I of course with it being a


higher time frame, it takes a lot more


price movement to get that to cross. So,


it's a little bit as of a I guess safer


move. So, you can do that. Of course, if


you watch it cross on the five minute or


the one minute,


price is going to fluctuate a lot more


on those time frames. Uh, but of course,


you'll get in the trade a little bit


quicker. Not a whole lot quicker, but so


it's just up to you, whatever you feel


comfortable with.


Okay. So, I'm going to go ahead and grab


my rectangle


tool


and I am going to mark off this fair


value gap.


Let me get this off real quick.


And I will go through and you know


there'll be more videos added to the um


the training education space I believe


is what it's called. Um,


and we'll kind of dive a little bit


deeper into fair value gaps, what causes


them, you know, what I watch for with


them, and of course, I'll go into a


little bit more about support and


resistance. So, you know, I'll kind of


break those down a little bit more in


the following videos,


but for now,


I want to see a fair value gap, which


will consist of three candles, three


consecutive candles. So, we have this


candle right here, and then we had a big


push in price and then a next candle. So


when there is a gap between this first


candle and this third candle


that is a fair value gap


and


usually price will want to come back and


fill the orders


that did not get filled when it had that


big push up in price. So kind of think


of it as a magnet. Uh you know price may


keep going but at some point it could


come down fill the orders


that were kind of left behind


and then go back in its intended


direction. So,


I don't know. Maybe an easy way to think


of it is say you're in a big group chat


with a bunch of people and somebody asks


three different questions. You know, are


we going out tonight? What are you


wearing? What do you want to eat? And


everybody starts answering and you know,


I'm wearing a dress. I want, you know, I


want to eat Mexican. But they missed


that third question. So an hour later,


somebody may come back and


answer that third question. So um you


know just think of it kind of like that


you know if you want to. So the


conversation kept going and then oh


forgot to answer that other question.


They came back to that initial


conversation thread and then the


conversation continued. So,


we want to go ahead and mark this off.


And I do if it is a green candle in the


middle, which is showing me


the direction,


then we will call that.


Hold on. I don't want that.


There we go. Okay. So we will call this


a bullish


fair value gap. Bullish is going up.


And then


right here on the tool colors, you can


come down and color it green. And then


same thing, you can fill it in green.


That way, if your eyes are just seeing a


fair value gap on your screen, you'll


know if price comes down and fills this,


you are going to be looking for buys uh


to go long,


bullish, whatever you want to call it,


but you're going to want to be going in


this direction. if price fills it but


doesn't come through and continues in


that intended bullish direction.


Okay. So once we have that


that's really you can continue to watch


it on the 15minute if you choose to. I


am going to hop down


to these lower time frames.


That way I can kind of show you some


other confluences


that I look for.


So you can see


for instance if I was on the one minute


time frame


you can see whenever price came up


and crossed my 4hour support


came down rejected came back up my EMA


had already crossed down here on this


one minute and of course when we have


pullbacks you'll see it come back to


that 21 EMA.


get away from it, come back because just


the price will fluctuate a lot more on


that one minute.


Same thing on the 5m minute. You can see


it crossed right here.


And then


at the same time,


I want to see


a W or


That is another confluence that


I really you know


want I guess to see um


if a trade can check off every


confluence that I have then


it's even better. So,


let me


show you this W


right here. So, there's a big one.


That's a thick line


right here.


And then price


continued up.


Okay, so


we have rejected off the 4hour support


continuation


crossing of the EMA,


a W which is showing us an uptrend.


We have a fair value gap


and then so let's see we're on the five


minute and then


get this off here so we can see this


better.


You can see we started creating


some higher highs.


some higher lows.


So, those are all good signs that we are


possibly going into an uptrend.


And then we can hop down to the one


minute. See if we see any W's on here as


well.


See right here.


You make that line a little bit thinner.


You can see that W right there.


And then I had you put the line chart on


your screen.


So, I'm going to switch to that.


And if you need to flip over to this to


kind of train your eyes to see the W's a


little bit better, then nothing wrong


with that. You can see there's a


W right there.


Okay.


Let's go back and


put that back where we want it.


Okay. So whenever I see a


bullish fair value gap down here near


this support


or same thing if it's up here by you


know the top resistance area


that shows me a you know strong sign


that price could go up. So, you know,


cuz we have it rejecting off this bottom


support, price will come down, tap in or


fill this fair value gap


and just I know some probably are okay


trading on the 1 minute, some maybe want


to stay on the 15minute.


Either is fine. I'm going to kind of go


in the middle


and


I would be good to enter.


So where price is right here you can see


this candle


whenever price went and broke that area


which is a break of structure. So, it's


showing continuation.


Broke past this previous high


and we're going to continue up. So, once


I see that break and of course my 9 EMA


crossed the 21,


I would feel comfortable getting in


this. So, I saw my W


price rejected off this bottom support.


We had the fair value gap that got


tapped into with this little candle


right there


and then we had a break of structure.


So,


let's see. This candle broke it.


So, I probably would have gotten in


around there if I was watching this


live. So


around


6:25


somewhere around there


my stop loss just to be safe I want to


put it below


the previous low. So, I'm going to get


it below this fractal.


And then, let me if I can


I'm going to bring this back just a


little bit.


about to where I would have gotten in.


Okay. So, you can either


initially aim for


the next area of hesitation, which is


this 15 minute.


I usually will always go for the 1 hour


or possibly the 4 hour, but I'll usually


start at the 1 hour. It holds a little


bit more weight than the 15minute, but


putting it at the 15minute initially,


you will be into profit. And then you


can move your stop loss up and if it


continues then you can adjust to the one


hour if you choose to. So, if you were


to do that, I would put an alert


right in here


and then that way you would get an alert


whenever price was getting close to that


15minute area and you would know, okay,


let me move my stop loss up to break


even or in profit and then move my


takeprofit up at the same time. So if


you want to kind of think of you know


this we have said this is kind of the


bottom support the floor this 4hour top


area is the resistance kind of the top


ceiling and then you know so that's kind


of what


I guess builds the house. So,


you know, you have your your house that


is built and then inside of it, you


know, you have a ball that is bouncing.


So, I don't know if y'all remember


like a video game or something, I think


from like the 80s called I believe it


was Pong. and it was just this little


ball that just, you know, went back and


forth and you'd have to move this little


thing to try to, you know, catch it and


not let it hit the ground. So, if you


want to kind of think of price like


that. So, you know, it's going to come


down, hit the, you know, the bottom


floor and then could come up,


hit the ceiling. So, those are pretty


thick walls that it sometimes have has a


hard time breaking past. And then of


course the one hour is kind of like a a


shelf on a wall. So it's still going to


have some resistance. It could the ball


could still come up, bounce off of it,


you know, come back up, bounce off of


it, but it's not as sturdy. So price


could just push right past it. And then


if you want to think of the 15 minute,


you know, it it still will hold


some weight, but you know, it's more


like a chair inside the house. So, you


know, you might price may trip over it,


you know, and kind of hang around, sit


down in the chair,


you know, kind of accumulate like it


kind of did back here. And then


eventually the ball is just going to go


right past the chair to one of these


other areas that kind of hold a lot more


weight.


So initially I'm going to put my takerit


up here


and then same thing I would set an alert


before my takerit. That way, if I'm not


watching it and I'm off doing other


things, if my alert goes off, I can then


pull up my chart and adjust at that


point if I need to or want to,


which I will usually always or not


usually, I will always move my stop loss


up uh to minimum break even. I'll


usually continue and just move it into


profit fairly quickly.


Okay, so we have our stop loss down


here, previous low.


We have our take profit. So, right now,


this is set at a 1 to8.


And don't feel like you have to always


do that. You'll kind of just play around


with it. And you know even a one one is


great. There is nothing wrong with that.


Okay. So we're going to go ahead and


play this.


Okay. So we came up. You would have hit


take profit if you would have had it


at the 15minute area.


And I'm going to wait for it to move


past there.


That might have been a news candle.


Okay, so once let's see where is my one


to one.


So once price is about at a one one


that's when I will start moving my


takeprofit or my stop loss up.


So we're going to move our stop loss to


break even


which


I usually move my stop loss up


with fractals.


So that's a good place. We're at a


fractal.


Of course, I would have waited until


that calmed down. It definitely looks


like news right there.


Okay. So, depending on if this was news,


I of course would not have moved it up


during that news event. Um, I would have


either tried to move it up before the


news hit to at least break even. That


way, in case it did do this crazy, at


least I'm out at break even. Um, if it


was not news, then, you know, we may


have already moved our stop loss up. It


may have still been down here. If it was


down here still, you would have been


safe. You can kind of see when I put


that crosshair. I don't know. we were


somewhere down in that area below that


fractal,


we would have still been safe. So,


I'm going to go ahead and just continue


to play this so we can kind of see


if it broke through. Okay, so it went


through our 1 hour.


might come back and get a retest.


So depending on how long you are wanting


to scalp, let's say we got in around


6:20.


Depending on when we would have moved


our stop loss up, we would have gotten


out at either 8:30.


If we would had not moved our stop loss


up yet


and we had our takerit right here, we


would have hit it at 855.


If you would have,


you know, went ahead and after this


candle calmed down and then moved up to


this fractal


and at the same time moved your stop


loss up,


you would still be in it. And of course,


we'll go over this in some future


training videos, but you know, moving


our stop loss up, you know, kind of see


would have gotten stopped out right


here.


Okay. So, I'm going to go ahead and


move this to


present.


So, um just that kind of gives you an


idea of


you know where I look for with support


and resistance. Uh fair value gaps if


there's any the W's the M of course the


MS would be a downtrend


and higher highs higher lows break of


structure. So I can


let me find.


Okay. So


we can go ahead and type this out.


Okay. Okay. So, we'll do a confluence


list.


Okay. So,


do W


forming


value gap.


Higher high.


Oh, what' you say in this uptrend?


Higher low.


Price rejected.


Support area.


9 EMA


crossing


21 EMA.


I think that is all of them.


Trying to think just to make sure I


didn't forget any.


Okay, so W or M formation fair value


gap.


Let's go ahead and


call this a


bullish fair value gap.


is filled which means it got tapped into


or price went inside it.


We see the higher high the higher low


price rejected


our support area


and our


9 EMA crossed our 21 EMA.


Okay. So now we have a list of


confluences that you can look at.


There are trades that I take that I


don't wait for every confluence.


You know, my risk tolerance is


probably a lot more than yours might be,


especially if you're just beginning. Um,


you know, if you want to wait until you


see this perfect setup, then that's


amazing. Go right ahead and do that.


That way, you know that it is you're


following all of your rules and if price


goes the way you want, amazing. If it


stops you out, it'll at least help you


know that


it was just the market wasn't anything


that you did. You followed your rules.


Everything was telling you that we were


going going to, you know, continue up in


an uptrend and


that just happens. So, by practicing in


a demo account and getting comfortable


with seeing everything,


you know, maybe setting your alerts,


um,


you know, and just kind of watching it,


then you'll kind of be able to see them


maybe a little bit quicker and just get


more comfortable with the confluences


And of course, like I said, if you get


stopped out, don't worry about it. Um


because you followed your rules. So,


let's see. We'll get that


on the list. And so, that is pretty much


the steps that I look for whenever I'm,


you know, kind of prepping to get into a


trade. Um,


and


it's just kind of as simple as that. Um,


it may seem a little confusing right


now, but I promise the more you practice


and play with it, you know, even if you


just kind of shrink this down, you know,


your eyes will just kind of get used to


seeing this little


ping or ponged, whatever that game was


called. Uh, you'll just kind of see it


bouncing, you know, up and down, up and


down.


And you know, we just learn


the higher time frame, the bias. Um,


you know, I'll go ahead and show you. If


we were to jump on the daily time frame,


we can clearly see


that we are in an uptrend.


And of course, each one of these


candles, since we're on the daily time


frame,


is 24 hours worth of data. So, this


candle is going to bounce. It's going to


fluctuate quite a bit in that 24-hour


time frame. So


by the time we jump down to our lower


time frames to kind of refine our entry,


you will see that


we can get into, you know, many trades


within


this 24hour period. So let's see from


So here's the 13th


if you follow. Well, price looked like


crap right there. So, believe that was


Yep. yesterday. That was Sunday.


So,


on the 14th,


let's see. And of course, we're still on


today's candle, but you know, you can


see how much movement


there was today,


you know, and we are still on this


candle. So, we might come up, break this


previous all-time high, and continue up


or it may kind of get to this area and


and do kind of the same thing. you know,


it may kind of bounce up and down for a


little bit.


And if you can see,


even on the daily time frame,


we have a really pretty


W.


So, price could


continue up. already broke that 4hour


top resistance.


All righty. Well, um so yeah, just


rewatch that video a few times and pull


up your own chart and just kind of mark


off the areas. If you want to go back to


that same chart and mark off those same


areas, go back to that same date I did.


If you're in Trading View, of course,


they have the replay


mode where you can kind of go back to


that date and get all of the most recent


candles,


you know, out of your view if you choose


to. Um, and then if not, just get into


the the live market on a demo account


and just practice over and over and over


and over and over. Um, demo account, you


can have as many as you want. So, if you


take some trades and


blow past it and lose it, that's okay.


um you know just start another one and


just keep practicing and it'll just kind


of become almost like second nature.


You'll just as soon as you open up a


chart and get on those time frames your


eyes will just see those areas and you


know they they will vary of course for


you know everybody.


what I see is an area maybe off a few


pips from the area, you know, where you


see or where you place your line. And


and that's okay. I mean, it is, you


know, let me


do want to show you one more thing if it


might help you.


Instead of using lines,


let's see. Let's go back to this date.


kind of get back to where we were.


So, if you, you know, and don't second


guess it too much, but, you know, if you


see this and you're like, "Oh, you know,


should I bring it down here? Does it


need to go up here? Where do I need to


go?" And and it starts just kind of


stressing you out. Um, you can also grab


the same little rectangle box


and you can mark out, you know, mark off


this area. If you do that, I would do it


a different color so you know it's not a


fair value gap.


And that way you just know that it's a,


you know, a marked off zone.


I just personally don't like it because


it it just puts a lot of different


things on my screen. But if it helps you


at first, you know, instead of just


doing this one singular line, then do


what you need to do. There's nothing


wrong with that. Um,


and you know, like I said, just just


keep practicing and it will get, you


know, a little bit easier and you'll


kind of create that muscle memory of


just looking at the chart, seeing those


areas of hesitation, of course, marking


off fair value gaps. if you want to


incorporate that and your eyes will


start seeing those higher highs, higher


lows, you know, lower highs, lower lows,


all of that. Uh the M's, W's, you know,


just once you just do it repetitively,


you will just see those a lot easier.


But but don't worry if you, you know, if


it takes you a little bit, and that's


completely normal. Um, I've been doing


this strategy for a long time, so it is


kind of second nature to me, but but I


do remember how it was at first, and it


was just like a foreign language. So,


um, don't rush. Go at your own pace,


what somebody else is doing on your


left, you know, versus what somebody's


doing on your right. Don't compare. Um,


and you know, just go at your own pace.


Practice as much as you can or you need


to before you feel like you need to go


to that next step of whether it be


getting a challenge account, starting a


live account, you know, just go at your


own pace. And I'm going to do another


video of, you know, just kind of


different things that you can do to


eliminate some of the stress and


probably more so anxiety that can come


with trading on the lower time frames


and different tricks that you can do to


help eliminate that. Uh but you know the


main thing especially if you see a lot


of chat in the circle you know people


taking trades and hitting a one to one


one to eight I don't know whatever um


don't worry about getting FOMO you know


don't the fear of missing out um I don't


know if you want to maybe think of


Romo instead


relief of missing out cuz they may have


gotten stopped out. You never know. So,


if it doesn't align with your rules,


then don't take the trade and do what


you need to do to keep yourself


as calm as you can while you're trading


on the lower time frames. Uh, but like I


said, I'll kind of do another video and


just go over some things that have


helped me through my journey of trading


on the lower time frames to keep me


calm, which is what what you want to be.


You need to be calm. Um, the charts can


be volatile, but you don't need to be.


So, um, okay. Well, go on and practice


everything on here. Watch the video as


much as you need to. If you have any


questions, let me know in the chat and I


will see you on the next video. Okay,


bye.$video_05_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_05_summary$Here Shea introduces top-down analysis and the habit of starting from the higher time frames before hunting entries. You'll learn how to mark important areas, read the bigger picture, and use structure to decide where price is most likely to react.$video_05_summary$
      ELSE summary
    END
WHERE sort_order = 5
  AND title = $title_05$Understanding Market Structure$title_05$;

-- Backfill watch-page content for lesson 6: Support & Resistance Mastery
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_06_transcript$Hey everybody.


I'm just going to do a quick video just


kind of go a little bit deeper into


support and resistance and what it is,


what causes it, why I like to use it.


Um, just in case you're either not


familiar with it or maybe just still


struggling a little bit with it. So, I'm


going to pull up a chart.


Okay. So, I just pulled up a clean


chart, took all lines off of it that


that I had on there, that way we could


kind of go down from the top down. Okay.


So, first I'll kind of let you know


support and resistance is basically just


an area where price


reacts to multiple times. So, um it's


usually caused by you know big


institutions.


It's an area where, you know, they want


to make it really cheap, so they can buy


it cheap and then they will push it up


to the next area and then sell it off.


That way they can get it cheap again and


it's just a a cycle. So, um, what we


want to look for is we want to find


those areas so we don't get trapped in


getting into a scalp at one of those


areas at the wrong time.


So we just kind of want to


go off of what the big institutions


what they are doing and the areas that


they are watching and use that for our


benefit.


So um you can kind of think of them as


the higher the time frame the more


weight they hold. So, I always start, of


course, with the 4 hour and mark those


off. So, I'm just going to kind of do


that and then we'll kind of talk through


each one.


Pull this down a little bit so you can


see this. So you can see that I like to


have my 4hour time frame a blue line.


And then so what I'm kind of looking for


is


where price has stopped. I try to go


most recent. So like previous day and


there are times that I may have to go a


little bit further back depending on if


you know price was just had a really


good run not many pullbacks


um you know or on the flip side if


there's a lot of consolidation and I'm


not really sure which area to you know


place it. So, let me get all this off


here.


So, I'm going to shrink my screen down,


which this, of course, we are at


the high. So, there's not going to be


much up there, but I want to show you


when I place my bottom one, my support.


So, the top line will always be your


resistance. That's what where price is


going to resist going


higher. And then your bottom, your


support, which if you think about it, is


um like the floor of a house. So, we're


going to come over here to this


horizontal line,


and then we're going to just kind of


find


where price stopped.


And you can kind of see.


Let me


get that out of my way where I can see


it.


Okay. So, let's see. And you can see I'm


kind of looking at these dates down here


on the bottom.


So, there's the 15th and the 14th. So if


we go to the 15th,


this was the lowest that price went.


And of course, it's a wick that kind of


dropped down. But


so I want to just kind of see if I can


So, if I place it,


place it there.


It's not supposed to be there.


So, you can kind of see price had a


really hard time getting below this area


over here. It had a hard time getting


above it. So you can see price has


reacted


off this area multiple times.


And


of course if


you're doubting where to put it, just


zoom out. And that can kind of help your


eyes see


an area. So, if you watch this little


dotted line, this crosshair, you can see


that area,


price had a hard time getting above it


over here. Then it had a hard it finally


broke through and then had a hard time


getting


below it. So, that's what you're looking


for. That's what you want to kind of get


your eyes used to seeing whenever you're


marking them off. And the more you do


it, the easier it'll get. And you'll


just be able to just go through them


pretty quickly and just spot that area.


So, we're going to we're going to put it


there for now.


And I usually So, I trade in the morning


uh around New York session open. So


whenever I wake up, that's whenever I


will adjust my lines if I need to


depending on what all, you know,


transpired maybe the day before after I


was done trading or through the night


and I'll just kind of adjust it and then


base my, you know, current trading day


off of those areas.


So we have our ceiling and we have our


floor. So


got our our house started


cuz remember the 4 hour will hold more


weight.


Those are kind of more


the more important


areas that you want to watch for.


Okay. So now we're going to do the same


thing with the 1 hour.


Ellie,


>> sorry, my dog is snor snoring down


there. Okay, so same thing. We're going


to grab our horizontal line.


And I want to be inside the house. So,


I'm going to kind of just do the same


thing.


And of course, this is pretty recent.


This is today, which was, you know, a


couple hours ago.


So I can kind of take that into


consideration, but I wouldn't


immediately, you know, just go there


without looking in the past.


So I can kind of see


right in here we have a lot of reaction.


I have this one as a red.


Try to keep that where you can see it on


each time frame.


Not.


Okay. So, if I kind of zoom out a little


bit,


you can see price


reacted


multiple times in that area.


Okay. 15 minutes and the 1 hour I


you kind of will still want to use that.


It still will hold weight even though of


course the 4 hour is kind of


like you're you're building the walls


and then the 1 hour you know you can


kind of think of it as like managing and


organizing your trades. Uh so you still


of course want to be cautious in those


areas. Uh but if it breaks through that


1 hour, it's fine. Don't feel like you


marked off the wrong area. Uh it just


may not have held as much weight and


price may be going, you know, to your


4hour support and resistance.


And uh on the 1 hour and the 15 minute I


only used one area of where I see that


hesitation. So I don't put a support and


a res a resistance on the 1 hour or the


15minute and mostly because it's just


too much on my chart. Uh, usually if I


see multiple areas where I can't really


decide where I need to put it, then it's


either because it's in consolidation,


you know, and if you kind of uh use


your, you know, this little rectangle


box, then,


you know, I would just probably stay out


of that trade and set alerts for when it


broke out of that area. But so yeah, on


the one minute or the one hour, I would


just do one one line.


So you can kind of see, you know, and


even going all the way back


to


uh July


9th, you know, price was still


reacting off that area.


Okay.


So now we go to the 15 minute


and


same thing


and see we did have some consolidation.


So


That was the 15th.


Just going to see where the 16th started


since that's the date that I'm recording


this.


I'm going to use this one first


and then once I get down to the time


frame that I'm going to scalp, then I'll


kind of look and see if I maybe want to


adjust that. And then of course if price


breaks through my one hour then this


little area right here is probably where


I would look at next since I do see some


hesitation in that area as well.


Okay. So I'm going to kind of pop down


to this lower time frame.


I'm going to just kind of show you.


You can kind of see


kind of like I had said before that, you


know, I don't know, maybe '8s game


called Pong, you know, where you had


that ball and you had to try to catch it


so it wouldn't hit the floor. Um, that's


just kind of what it reminds me of. you


know, it'll just come down, up, down,


up, down. And that as a scalper is what


I want to trade. So, you know, you can


and depending on how consolidated it is,


um, you know, on how far you can ride


it. So if you look back here,


you know, we had movement that went all


the way up to the support or the


resistance and all the way back down to


the support.


And then you can see they're kind of


accumulating down here, accumulating


orders.


And then this is where you will just


kind of use all of the other confluences


that you know we go over to decide if


we're going to break below this or keep


going up in price. So


that point I will


jump onto the higher time frame


and I will put a purple line which is


just you know what I just call like my


breakout destination.


So


this


I will put on the wicks cuz I want to


know where the for this one this is NAS


this purple line is


you know that price right there that


23,000 is the all-time high. It's the


highest that NASDAQ has been. So, I just


want to know that if it does push past


this ceiling that this area could be a


very good area where they're going to


try to get price to again.


And then I will do the same in case it


breaks below this.


I want to just do the same thing. I want


to look for that next area of


hesitation.


So you can see had a hard time right


there. Hit it right there


when it was over here. Had a hard time


getting above it.


So I just kind of want to see all of my


parameters in place.


And then you can kind of see if I drop


down here.


So whenever price comes down below this,


you can kind of see it just kind of shot


down and then came right back up. That's


what we call a liquidity grab. So the


big institutions they know that us


little you know baby traders


um according to them is um


paying attention to these levels. So


they know that whenever we are say


getting into a buy over here,


more than likely


wherever that you know you would have


gotten into


you would have set your stop loss


somewhere below this support level you


know maybe even below that previous low


which is what I prefer to do.


So they know that they know that we are


watching that area and whenever we see


it going into an uptrend again that we


are going to place our stop loss


somewhere in this general area you know


and they may be just kind of looking


you know all in here. Everybody's kind


of different with where they want. Some


are a really close stop loss. um you


know but they they understand that that


we are looking at that area for a stop


you know stop-loss placement. So


whenever you see these big wicks


right here,


which if I


circle that and then come up to the 4


hour


or even the 1 hour,


you can see that it's just a wick. They


came down and then immediately bought


and started moving price back up. So,


get back down here.


So that's why whenever I'm marking off


my support and resistance, I like to go


to the candle body if possible because


that tells me that that is actually


where price stopped and not where there


was maybe some, you know, liquidity grab


and it was just a wick. Uh the only time


I may adjust that is if there's multiple


wicks that kind of come down into that


area. And then, you know, I'm okay kind


of adjusting that a little bit, but I


try not to adjust it too much. And so I


just kind of see that as a liquidity


grab and then they just start moving


price back up. So you can just kind of


see how price just


does a, you know,


pingpong between these areas and then of


course we see a breakout


breakout up here.


Price got to this one 1 hour area. Then


we start seeing that accumulation again.


They're kind of just deciding, are we


going to go up? Are we going to go down?


you know, we're going to accumulate a


lot of orders and then we're going to


sell off to get it cheap again and then


we're going to accumulate again and then


we're going to buy cheap, push price up.


And so you just are wanting to


ride the waves of all of that.


So um


another thing is if you are ever looking


at my chart and say let me get on a


little bit higher time frame.


So say you see that my 1 hour for


instance


is


right here.


So my 15minute is this orange line and


my 1 hour is this red. So say whenever


you're marking your charts off, you have


it, you know, where your red


your 1 hour is right here and your 15


minute up is up there. They're, you


know, a little bit different than mine.


And and that's okay. I don't necessarily


worry too much about the time frame or,


you know, if the color of our lines


match. Just know that um, you know,


we're both seeing


the same area of hesitation and we're


both marking it off. So, we're just


almost seeing it with a different lens,


which is fine. Just be cautious with


each area. And you know, you may see


that if I have mine marked off as a


15minute and you have it marked off as a


1 hour


on my chart, price may push past that


15minute area pretty easily


and then go up to, you know, my 1 hour.


And you know on yours it may do the


opposite. So um you know price just may


go straight to your 1 hour and start


accumulating from there. So just use


caution at at each one and you know


maybe set alerts if you don't if you


just want to get your lines up and then


not have to sit here and watch the


chart. Um then just set alerts


you know at around each area. So say you


know of course we can see


prices coming up


and we'll see if it gets to this you


know my 15minute area and starts kind of


accumulating or if it's just going to go


straight up here. So


I'll maybe set an alert right there.


That way I will get notified


if price comes up past that one hour. So


if it does and it truly breaks that


level and I start seeing all of my other


confluences, then I might start looking


into if we're going to continue up to


maybe my top resistance. And of course


if price


did do that. So say we come up.


Let me see if I can


make this a little bit thinner.


Okay.


So say if price did come up,


came down, failed to go below it,


came back up again,


failed again,


then started giving me my higher highs.


So say it comes up here,


breaks through that area,


we have a retest,


and then we continue up. Maybe it's


going to make a new all-time high. So,


at that point,


this top resistance, which was my


ceiling, would then turn into


my bottom support level. And then


depending on whatever price did, you


know, if it just continued on, you know,


we have pullbacks, continued up, you


know, we just keep doing this.


Then whenever I come in the next day and


I'm adjusting my lines,


then I'll look and put a new line.


And then that will then become my top


resistance.


and this will then become my support.


So, you know, you will just kind of be


adjusting that


just know that if even if it breaks


through it, it's okay. Your resistance


can turn into your support and your


support can then turn into your


resistance. So,


I hope that helps. Um, I did put, you


know, right here just in case you want


your chart to be the same color as mine.


Um, and then of course, like I said


earlier, if you're ever in doubt, just


shrink up your chart and sometimes


that'll help your eyes kind of see an


area, you know, that price has reacted


to in the past. So, not necessarily


how many days. Um, you just want to look


for the area that you know you see price


reacting to multiple times. If you can


go most recent,


to me, that's what I prefer to do. But


it doesn't always happen like that.


Sometimes I have to go back, you know, a


month or so if it's um really trending.


So, just try not to concentrate too much


on that. Just beware when it gets to


those levels that price could pause or


reverse. So, I hope that helps. Let me


know if you have any other questions


about the support and resistance and we


can kind of touch on it again in another


video. Okay, thank you. Bye.$video_06_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_06_summary$This lesson explains what support and resistance really are, why they matter, and how Shea draws them on the chart. You'll learn how these areas form and why they become the backbone of the rest of the strategy.$video_06_summary$
      ELSE summary
    END
WHERE sort_order = 6
  AND title = $title_06$Support & Resistance Mastery$title_06$;

-- Backfill watch-page content for lesson 7: S&R In Practice
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_07_transcript$There we go.


All righty. So on this one, I'm just


going to kind of we're going to go over


uh our support and resistance lines


again. So as you can see, as crazy as


this like looks to even me, it's like a


very naked chart. But I just want to get


all of the lines off of my screen and


just start with the top, you know, down


analysis.


And we're just going to mark up a couple


of charts and but I want you guys to see


where price, you know, is respected,


where it rejects, and


just kind of make it to where, you know,


hopefully with practice, you can kind of


see what I'm looking at and what I look


for whenever I am marking off my lines.


Okay. So,


first of all, since I deleted all mine,


I'm just going to put


put me some lines on the chart real


quick. So, I know


um you know, I'm going to have a


4hour support and resistance. Then, I'm


going to have my red 1 hour.


And I'll also put a little box of what


my colors are. So, I'm just going to do


this for now. Um,


hold on. Sorry. I have a back brace on


that's heated and I think it keeps


giving me hot flashes.


Um, okay. So,


let's get these out of the way.


And then if I feel like I need a caution


line, then we'll add that, you know,


later. But, okay. So, first of all, say


I'm just looking at the charts fresh,


you know, whatever time it is. Usually,


of course, I do it first thing in the


morning. I'll kind of just check to see


if I need to adjust anything. And then


whenever market closes, I will do the


same thing. I will adjust kind of


depending on what price did throughout


the day and okay so first of all I


always start with my 4 hour


and I want to see where price kind of


hit multiple times and rejected. So you


know hit a price stopped multiple times


and I will also use this crosshair over


here. You can find it in this menu. I'll


use that to kind of help me look to the


left. So,


I'm going to look and then down here on


the bottom of the screen,


you know, where you can see your dates,


I will watch that as well to find out


how far back I'm going. So I always try


to get pretty recent if I can but at the


same time when I do that I am also


looking to the left because if I can


find where price stopped say we'll start


with this. So


so here is


let's see today is Monday. So you can


see


there's Friday, Thursday,


Wednesday, Tuesday, Monday. So right


here, starting this area, that's already


a week out. So


I'm going to look kind of most recent.


So, a lot of times I might not include


like say Sunday


uh if I'm marking up on a Monday, but


cuz sometimes price just may not move


much on a Sunday.


Okay. So if I go to Friday.


So I'm going to kind of line it up with


initially the candle body.


There's a lot of times that I won't go


with the wicks. Uh sometimes if there's


multiple wicks, then I'll kind of uh


include those. But initially I want to


just kind of see if the candle body if


it lines up to, you know, anything else


going to the left. So you can see if I


just go off of this candle body, it kind


of hits some wicks, but it doesn't


really line up with necessarily any


candle bodies. If I go to the tip of the


wick,


you can see, you know, price rejected


with candle bodies multiple times here.


These candles came down and we stopped.


You know, almost think of it like the


floor and the ceiling. So, you know,


bounced off, came up, bounced off, you


know, had a had a hard time getting


below that level. And then of course


once it finally did break, I got


something here I want to delete. Once it


did finally break, then of course price


tried to come up and go above that area,


failed, came down, tried again, and you


can see, you know, it just had a really


hard time getting past that level. So


that's initially what I look at. So you


can see if I kind of shrink down my


screen,


you can see that it almost is like I


created this ceiling right here


where price really did not want to go


past. So that is what I will use and


label


as my four whoops


4hour resistance.


And then I will go with my 4hour


support. So that will be like the floor


that I look at.


So I'm going to


kind of shrink it down a little bit, but


not too much where I can't see candles.


So same thing with this.


I want to look and see.


Let's see. So, that was Friday.


So, first we're going to go with this


Friday


low right here.


And once we get to that level, then I


want to look and see


how it kind of lines up to the left. So


you can see we had some hesitation here.


We did have a little breakthrough, but


of course that could have just been a


liquidity grab. But you can see price


had a hard time getting above it here.


Even if you go all the way to the left,


price really kind of hesitated. We


hesitated here, here as well. Had a hard


time getting above it. Had a hard time


getting below it, you know. So, you can


see that it kind of lines up looking to


the left. Again, if I kind of shrink


down my screen a little bit, you can see


that, you know, we kind of created a a


floor.


So from there I will then go of course


to my 1 hour.


My 1 hour is my red.


And then same thing.


So the higher the time frame the the


more weight that I hold you know to


those support and resistance levels. So,


um, you know, once I get to my 1 hour


chart,


I want to mark it off where I see the


most hesitation.


So, you can see like my eyes instantly


go to this area. You can see price


really had a hard time getting below


this area. And, you know, even when it


was below it, it kind of had a hard time


getting past it. Even if you look, you


know, all the way back like down here on


the bottom, I mean, we're on, you know,


in November the 11th,


the 5th, you know, so that was a pretty


strong


level for almost a month. And you know,


so if you just shrink your screen down


and you can kind of see that there was a


lot of hesitation in that area. And it's


the most hesitation that my eyes kind of


immediately go to on this one hour chart


that's in between my 4hour resistance


and my 4hour support which hold on real


quick. I'm going to


label this one.


Okay. Then of course I'm going to just


label this


1 hour


resistance.


All right, continue on. I'm going to go


down to the 15 minute


and same thing. Kind of shrink that


down.


And a lot of times I will notice with my


15inut it's not it doesn't always happen


like this but I will usually try to mark


off if there's a hes like an area of


hesitation that ends up being closest to


current price. Okay. So, even though


there is a lot of hesitation up in here


with current price being down here and I


see


this level of hesitation right here,


you know, there are like a lot of times


I've noticed that I will initially mark


off that level and then uh well, I'll


just stop there for now before I


continue on with the caution. But um but


you can see, you know, kind of shrinking


this down.


Same thing. Well, won't let me go back


too far, but


same thing. November 17th,


you know, even on the 20th, there's a


lot of hesitation. I mean has a pretty


strong support during you know this


week or so this kind of time frame right


here.


So for now I will keep that as my


15minute


resistance area.


And then like I was saying my kind of


ones that I've pretty recently started


adding is anywhere that I


see hesitation.


in addition to my main kind of four


lines that I will always have on my


chart is the area of caution. So, I I


feel like I've been doing it a lot here


lately, but it's because the charts have


seemed to, you know, go into


consolidation


pretty often. And so it will create


these little levels of


just resistance. And so I just want to


be aware of them. So of course you can


see you know there was a lot of


hesitation in this area.


Sorry.


Sorry. My dog's dreaming.


Um okay. So yeah, I will just put this


little level of caution in case whenever


price does come back up there,


I want to be aware of it. And you know,


a lot of times these will all kind of


flip. So like where I have maybe my


15minute


area if price comes back up you know


maybe this afternoon or yesterday or


Friday you know they kind of may all


flip around where this maybe was my


4hour resistance at one time and then


maybe it turned into a 15minute


resistance area. Uh, but as price moves


to different, you know, levels, then


whenever I'm going to like remark up my


chart and adjust any of my lines,


I may kind of like flip them around with


what is closest to current price, if


that makes sense. So, you know, the main


thing is that you just have that area


marked off as an area where you do see


that resistance that's hit quite a bit


and you know just be aware of it. So um


even though like always I am more aware


with my 4hour support and resistance


uh but at and less concerned about say


this caution area especially with price


being this far down


but at the same time I am aware and


cautious with each one. So even though


the 15minute to me doesn't hold as much


weight as say the 4 hour or the 1 hour,


I am still aware of it. So initially I


may, you know, put my take profit near


my 15minute resistance area and then


depending on what price does then I and


if I'm watching it or if my alert goes


off, I may move it up to my 1 hour. But


I am aware of it. So, even if I put my


takerit


at my 1 hour resistance or heck even all


the way up here to my 4hour resistance,


I will have alerts set before each one


of these because I want to be alerted of


that and depending on where my take


profit is, I want to look at the chart


and kind of determine if I'm going to,


you know, just go ahead and take profit,


maybe move my stop loss or whatever it


might be.


Uh, but I want to just I want to be


aware of that. So, you know, just of


course the main thing,


excuse me, the main thing is that you


are just aware of each each level. um


you know whenever your price is getting


near that zone and then of course y'all


know that I will also add


my breakout zones. Um,


so let me I will also put like with uh


NAS and gold since they make the


all-time you know recent highs I will


always mark that off just I just like to


be aware


of where the all-time high is because


there's usually


a lot if price does get up to that area,


you know, like you can see it tried to


like retest it a little bit.


Uh, you will see a lot of hesitation


usually near that area.


So, I will I don't know why I just


always name it breakout destination, but


I'll have all-time high behind it.


And then I would get on my 4our chart.


Excuse me.


My's getting dried. And then I will mark


off where if price were to continue down


below this 4hour support level,


I want to go and look where that next


level of hesitation is. So,


you know, and usually at some point it


may have been maybe my old 4hour, you


know, support or resistance or at one


time it may have been one of my areas uh


that was marked off as a area of


hesitation, you know, support or


resistance.


So whenever I look at this and I again I


will use my crosshairs


to determine.


So I may


I may go here initially even though you


know price obviously got pretty close to


coming down here. So depending on where


price goes throughout the day, whenever


I am adjusting my lines at market close,


I may move this 4hour support down, you


know, closer to where this came down to.


Just kind of depending on what where it


stops and if it lines up to anything to


the left. Um and then at that point if


price actually does come down then


that's where this breakout zone I would


just of course again look to the left


and come to the next area. So which


would


probably be


maybe this area. So you can kind of see


So, you don't use your daily time frame


for your breakout destinations. You use


the 4 hour. I usually use the 4 hour.


Like sometimes if I'm looking at the 4


hour and I'm kind of like questioning,


you know, or if it's just maybe not an


area that is very clear to me, then


sometimes I will hop over to the daily


time frame and you know just kind of see


if maybe something sticks out more or


you know clearer on that end. But a lot


of times with the 4hour and it may be


because there has been so much,


you know, like ranging going on that


those support levels are pretty, you


know, kind of


visible. I guess I a lot of times I've


noticed that I can do that with just the


4our chart.


So for now, I would probably keep


this area as my first breakout


destination.


And then even though price is not up


here,


I will do the same thing.


Of course, our all-time high is right


there, but I want to mark off


this area.


My chart will move. So, you can kind of


see price had a hard time going above


this. And then same thing, it just


there's quite a few bounces and kind of


ranging in this area. So again, if price


were to come up and look like it's


heading back up to that all-time high,


I want to be aware of that first


breakout destination


just in case it may be like a fake out


or, you know, it could start coming back


up here, get to this previous level of,


you know, resistance and bounce off of


that and come back down and not even


make it up to the all-time high. So,


just because I see this hesitation,


I just want to be aware of it. So,


again, that's kind of how I use the


breakout destinations.


And I will go ahead and put


I think most of you already know um


kind of what what colors I use, but I


will have this on here just in case if


y'all want to screenshot this or if


you're watching the recording,


you can kind of go back and


and look.


Let's finish off that word.


And then my caution


yellow


breakout purple.


And that's bugging me that half of that


is capital and half is not. So let's fix


that.


Okay, there we go. So, that's kind of


the colors I've always used. I don't


know why, but but they just stuck with


me. So, you know, even if you want to


use different colors, then I would just


make sure that you either put it on your


chart or a post-it note or something


until you kind of use them enough to


where you just know what they are and


know what time frame it is. But, so


obviously you don't have to use the same


colors as me. Um but yeah, so that's


kind of the general idea of


what I am looking for whenever I mark


them up. And you can see once you know


you get down to


say this 1 hour chart or sorry 1 minute


you can see


you know it it can get kind of busy


especially if there's been a lot of


consolidation.


you'll see that, you know, the


different time frames are maybe a little


bit close to each other, but a lot of


times you can still get at least a one


one between each one of these. And and


there, you know, you should be okay with


the one. There's nothing wrong with


that, especially with the way the


markets have been. And of course it


being December uh aiming for just a one


one is


the best honestly because you know a lot


of times say if you are kind of riding


this wave of in between these ranges


getting a one to one and it will reverse


you know so you may get stopped out and


then it'll turn around and come right


back up. So just try to aim for maybe


that one one while the markets are a


little janky. Um and


you know and just kind of see if of


course you do want to aim for something


bigger


that's fine. just just I guess know that


there could be a good chance that it


could turn around or protect your


capital and move your stop loss to break


even or maybe a little bit improfit even


if you want to. Uh because yeah, the


markets have just been crazy lately. So,


um,


trying to think. I'm also deleted.


Where's my gold? Oh, there it is. So, I


also deleted my lines off of gold.


So, we can


kind of go through. Actually, hold on.


Let me get back on this chart. There was


something I was going to let you all


see and screenshot if you want to. I


kind of just made a quick checklist


for you to kind of go over whenever


you're marking up your charts. Okay. So,


whenever you're looking at your support


and resistance, you know, just kind of


look at, you know, did price bounce or


reject from this level multiple times.


Um, are there clear wick rejections or


body closes at this level? Of course,


like I said, for me, I always prefer to


go with the body close because sometimes


the wicks can be just liquidity grabs.


So, it's not necessarily where I view


price as stopping. I I just view it as a


liquidity grab, a sweep, and then it


come it turns around. So, I always will


go off the candle body. Um, and then of


course, is this zone respected across


multiple time frames? Um, before I go to


gold, I want to show you kind of how I


confirm my lines. Um, and then of course


also mark structure zones where price


bounced off clearly bounced off and went


up. If you think of like maybe a


trampoline or something, uh, that's your


support. If it bounced off and then went


up, if it got rejected and fell, that's


the top, the resistance, the ceiling,


um, tested a level multiple times or,


you know, created a clean obvious


reaction and stopped. So, uh, you guys


can take a screenshot of that if you


want to. Again, put it on a post-it


note, put it on your chart, and that way


you kind of can go through and ask


yourself each one of these as you're


marking them off. Um, and then also I


almost forgot whenever I am marking them


off to kind of determine


and if I'm going to um, you know,


consider the w the wicks or not.


I will always go down to my lower time


frames and I've noticed the five minute


seems to be like my happy time frame of


double-checking my areas. So once you


get down to the 5m minute time frame and


of course you can't uh shrink it up too


much because it just won't let you but


but you can see like this 4hour


resistance


you can just kind of double check with


this 5 minute time frame that it does


you know price did stop at that area.


Same thing with this caution. Of course,


that was probably say a 15minute or 1


hour, maybe even a 4hour resistance at


one time cuz there was a lot of


hesitation right there.


So again, if price comes up throughout


the day and I'm marking them up, you


know, when market closes, this may end


up turning into a different time frame.


But same thing with the 1 hour.


So you can see if I get my crosshairs


price seemed to stop more up in this


area. So that was Friday


actually. No, that was like a week away.


So let's see. Let's get a little bit


closer.


Okay. So, here's Thursday.


So, this is where you can adjust it if


you need to.


So, I'm going to look there's Friday.


Where was this?


>> Thursday.


So, I may adjust this just since price


kind of stopped right here on Friday.


I may adjust up to that candle.


And of course, you can see that it still


matches up back here.


Same with the 15minute.


It won't let me go back that far.


Okay. So, you can kind of see that price


definitely kind of respected this area.


And even though we have this up here, I


would I see more hesitation in this


area. And again, that could have just


been a quick, you know, quick sweep. If


you look down at the time, it was New


York open. So, you know, that could have


just been a a fake out.


So, I will


keep it where I have it for now. I won't


go up to this candle.


And then, of course, same thing with my


4hour support. I would do the same


thing.


Double check if it lines up with


anything back here.


And again, since price continued to come


down,


I can see that if I move this and adjust


it a little bit,


it lines up more with this level.


And of course, same thing here. That


could have been a quick sweep and price


respected that level. So then if you go


back and if I show you on the time


frames, you can see that you know it did


consider these wicks. So, the fact that


multiple wicks went up to that zone or


that price whenever I go down to that 5m


minute time frame and it the candle


bodies kind of seem to line up more in


that area. It's because, you know,


there's multiple wicks. So, it wasn't


just one quick wick rejection. There was


multiple times that those wicks went to


that area. So, it did kind of create


more of that area of resistance. So, if


you're ever kind of just secondguing on


if you have your zone correct or, you


know, questioning if you should uh


consider a wick or just stick with the


candle body, then always go down to the


5m minute time frame because um you


know, I know a lot of this can be kind


of subjective, but um you know, instead


of like there are some whenever they're


marking off areas that you know they


will do this they will do kind of candle


bodies


and to them that's their 4hour whatever


I'm on 4hour support level so they will


consider like a whole area and I don't


know why but I just it's too busy on my


screen especially if I have fair value


gaps um it just is almost too much for


my screen. So, I think that's why I


always prefer to just do my one line,


but I am always aware that that it is a


zone. It's not necessarily, you know,


exactly at this 25,


154. like if it doesn't quite get to


that area and then starts going back up,


you know, I won't dismiss that. I won't


be like, well, you know, price didn't


quite get down to my 4hour support, so I


don't know if I'm going to consider that


quite a rejection yet. Um, I just know


that it could be an area. and you know,


so just know that whenever you're


marking them off, I think that's why me


going down to the lower time frame and


kind of checking with the uh like the


five minute candles where price where I


can like kind of see it stopped multiple


times and there's more, you know,


candles. So, it sometimes is a little


bit easier to kind of fine-tune


your lines a little bit. Uh, but also


just know it is an area. It's not just a


line and price may not get quite to


that. Even though I do feel like a lot


of times whenever I mark off my areas,


price will actually reject off of it.


Um, or break through it, pull back into


it, you know, all of that. But there are


times that, you know, price may not


quite get to that before it maybe turns


around and continues to go back up. So,


always keep that in mind as well


whenever you're marking them up.


Um, and then if you guys want to, I did


clean this chart up as well


if you want to


go through it together and mark it up.


Um, if you want to, I can pull up my


chat and if y'all want to kind of see


where you think maybe price would be on


where you see that hesitation,


then we can do that. If you feel like


you kind of want that practice


with me, you know, on a call, we can do


that. And if not, definitely don't have


to. If you think just me kind of kind of


going through the Nash chart helped you


enough, uh, then we can just do that.


But for now, I did take off my lines on


gold.


in case y'all wanted to, you know, kind


of go through it together and y'all kind


of decide where you would maybe put your


line and see if I agree with that or


not. So, you guys just let me know in


the chat if you want to do that. If not,


we definitely don't have to.


Okay, that's fine.


I definitely get that.


Okay. All right. Well, we will


definitely do that and I will and again


come off mute if you want to. I do have


my chat up, but um but if I miss a chat


come through


then


let me go ahead and get


my lines up. And then


if you think you want to come off mute,


then


you can just come off mute if you want


to.


and we can go through it together. But


until then, I'm going to go ahead and


get


get these labeled on here. I don't know


why I didn't just like grab my lines and


move them out of the way, but no, I just


deleted them. So, I got to get all of


them back up here again.


Okay. So for now we will just do our


kind of our core four lines.


Okay. So, does anybody if you have your


chart up


um


does anybody want to put in the chat


where


like on your chart kind of using these


crosshairs where you think you would put


your 4hour resistance? We'll just start


with that one.


So, we'll bring this one. Get these out


of the way.


Okay. So, 4381.7.


Okay. So, a 4hour resistance


4381.


Okay. Let me let me put that there.


7.


Okay, now I got to let me move my chat


box over here so I can see to the left.


Okay, so I would definitely agree with


that. So y'all can see kind of what Lisa


was seeing.


If you look to the left,


you can see that it even matches up over


here.


So, I would definitely agree with that


one.


Okay. Does anybody want to give me


numbers for the 4hour


support kind of the floor?


And I can shrink my screen up too in


case you don't have yours on.


Let's see. Who's today? 15th.


Does anybody want to give me a support


number?


I'm going to act like I don't know what


I'm doing. Y'all got to give me numbers.


Okay, there we go.


4209.


Here, let me just do this.


29.1.


Okay. Whoops.


Not that far. 1.


Okay. Yep. I definitely


agree with that one as well. Let's see.


Yep. I think I like that one, too. You


can see price had a little bit of


hesitation here. Of course, same thing.


Hesitation, hesitation again. That could


have been just a liquidity grab.


Had a hard time getting above there.


hard time getting below that area.


Delete that box.


Okay, let's see.


Yeah. So with this one, um this is one


that again I agree just because you know


these candle bodies here and then you


can see candle bodies here like these


did close a little bit above. Same with


these up here. Like if you look at my


crosshairs


like right there. So, but this is one


that once you get down to that lower


time frame, that 5 minute, you can see


if maybe you need to adjust to not um


you know, not consider maybe that wick.


Uh but for now, we'll kind of keep it.


We'll keep it there.


Uh let's see.


Okay. 42. Let's see. Where did that


message go?


Okay. So, Lisa said I would have gone


4219.


Let's see. Let me


Okay. Yeah. So, that's kind of more of


like the candle body. Um, and yeah, I


agree. I agree with what you're seeing.


Uh,


but again, kind of like I was saying


with like the zones,


a lot of people whenever they're marking


off their zones or they if they want to


block it off, they will almost go with


the whole candle body in that zone.


Okay. So, you know, they may look at the


top of this candle, the bottom of this


one. So, you know, it could be like that


whole area. Um but again, you know, once


you get down to that lower time frame,


we'll kind of double check and see where


price maybe,


you know,


um I don't know what word I want to use,


but where it probably stopped more on


the lower time frames. And that may kind


of get make it to where our eyes see see


the price that area of hesitation a


little bit better where we're not


considering all these wicks that


happened on the 1 hour or sorry the 4


hour. Okay. So now I'm going to go down


to the 1 hour.


Sorry. I don't know why, but this box


just


keeps catching my eye.


Okay, so let me


kind of shrink this up. Okay, so Jill


said 42


4290.7.


Okay.


Yes, I definitely


see what you are seeing.


All right. So, if y'all can see price


hesitated here. So, even Friday price


hesitated.


Thursday price had a hard time getting


below that.


uh you know even going into that


previous week uh price had a really hard


time getting above that. So


all right I can definitely see what


you're seeing.


Yeah. So Kristen 4296.


Let me get my crosshairs there. And


again, that's probably like the candle


body


right here that you were seeing.


Yeah. So, that's kind of where you know


the looking at the wig versus the body,


you know, where you may we all may be


kind of a little bit off, a few ticks


away, you know, just where our eyes kind


of go to. and you know if we're taking


into consideration candle body candle


wick uh but you know just kind of being


aware that it's more of like a zone than


y all definitely really close so that's


that's good


okay now the 15 minute see how how much


I can shrink this up for y'all


Okay, let's see.


Okay. Does anybody have a number for the


15 minute?


come up here and grab


my 15 minute.


And don't look at where I put that. Even


though that kind of landed right at a


zone, don't think that I'm thinking


that's where it needs to go.


Okay, let's see. 42


4250


6.


Okay, awesome.


I like it. I like the looks of that.


Okay. So, uh, Tammy, real quick, I'll go


ahead and


show you kind of what I mean with a


zone. So, like if you just kind of look


at almost where like the tops of that


is, the tops of the candles are. Whoops,


I didn't mean to do that.


So like right here if you look at kind


of where price stopped


you know in that area where the number


the price Jill had mentioned and then of


course where price you know the candles


kind of bounced off on the bottom which


a lot of times is just that


consolidation area or zone.


But you know a lot of like there are


some traders that whenever they're


marking off their support or resistance


they will do this block uh but they're


just kind of marking up the top and the


bottom of you know this kind of


resistance area. Not necessarily, you


know, these I guess sometimes they will


depending on how big they want their


zones to be or how you know they may not


even consider maybe the 1 hour or the


15minute area. They may only mark off


say the higher time frames depending on


what time frame they execute their trade


on. They may only consider maybe that 4


hour. And so, you know, in that case,


they may block off this whole area right


here, just this whole mess really, and


know that, you know, if price comes down


and gets into this whole zone area, then


they would look for a possible


rejection.


So, I've never really marked off


necessarily uh those zones, but but I've


seen I guess enough people do it to


where um you know, I know they're just


kind of blocking off the whole area.


Uh okay, let's see.


Okay. So, I'm going to


Let's see. We're going to put one up


here. 427.


I can Let me just type it in.


4217. Yeah, because like Lisa said,


getting it closest to current price if


there's enough hesitation.


>> I think it was uh 4 431.


>> It was I was like that don't look right.


That's not where I wanted that to go.


I've done that before and like typed in


I don't know some random number. Usually


it's like NAS where it's like multiple


numbers and it'll be so far off my chart


that I'm like one of these years I'll


run into that support line


that's like I will shrink it up and it's


like out in space somewhere.


Okay. So yeah, like Lisa said, if you


are marking off closest to price, uh the


one thing that you know, I mean, if you


scroll to the left, you can look. Uh but


you know sometimes it just depends on


if you can see something I guess to the


left to kind of um correspond that with


on you know if you want to move it to a


15minute area uh line or a caution. So,


um, but you can see Thursday,


you know, we had a bounce, had a hard


time getting below this, and then, of


course, current price,


we're getting a little bit of rejection


here.


Okay, so let me go look in the chat.


Uh, can you show again how far away from


your lines you make your alerts? Um,


okay. So, I would say like if I'm in a


trade or if I'm, you know, maybe


debating on getting into a trade, but I


want to wait for, you know, maybe I'm


looking right here and I'm like, I want


to wait for it to get down to one of


these levels. Um, then I usually of


course will do it on like the one minute


time frame. I guess it just gives me


maybe I feel like I have more time to


like if my alert goes off, I have time


to look at it, assess it, even have time


to like set a pending. So, like for this


one, if I was wanting an alert near this


uh 15minute area,


then I would probably put it, you know,


maybe


like right here using this one as an


example, just because there's a little


bit of hesitation right here. So, I


would almost use that as maybe like a a


unofficial break of structure. So, if


price does get down below this, then I


would look at my chart and know, okay,


price is coming down. It's getting


pretty close to this 15 minute


resistance level. And so, that's where I


will kind of start looking. Okay, am I


seeing it hesitate? are we still


getting, you know, lower highs, all of


that stuff. Um, and then of course, you


know, same thing up here. If I want to


see if it's getting close to this 4hour


resistance, I would maybe use like this


area and just let me know, you know, if


price gets


breaks above all of this mess right


here, then I'll look at, you know, on if


we're going to get past that 4hour


resistance or of course a a bounce off


and or rejection.


to come back down. But again, that's


only if like I'm not looking at the


chart. Um, and honestly, even if I'm if


I stay in my office, but I don't want to


just like stare at the chart, then I'll


set those alerts. Um, or if I'm maybe


looking at other pairs and setting


alerts on there or, you know, already in


another pair, but I want to just be


alerted if gold or NAS, you know, gets


to a certain level, then I'll do that


also, just so I don't have to keep like


bouncing back to that chart to see what


it's doing. And if it's ranging, then


you know it's just kind of a waste of


time for me to keep looking if every


time I look it's just staying in this


barcode.


Um


okay you're welcome. Okay. So yeah from


there so once we got those marked off


then of course that's where we will come


down to the 5 minute and look. So of


course that was Tuesday. This is where I


will kind of look at dates to see how


far back I'm going.


Okay. So here's Thursday.


So, I can already tell


this one. I'm going to go ahead and move


up


just more to where this area


was hitting. And if price continues to


kind of if well basically if it doesn't


come all the way back down to my support


level, I can already kind of just look


at this and tell that whenever market


closes today, I will probably move my


4hour support up. Um I don't know. I


guess depending on just again what it


does, if I would move it up to


Friday's low or not, if I


kept it on Thursday, I would maybe move


it up more to this level just since it,


you know, kind of stopped here multiple


times. And of course, if I use my


crosshairs, you can see that, you know,


even looking to the left that it kind of


lines up with another level where price


really kind of hesitated at that area.


So, you know, depending on what price


does today, um, you know, if we continue


to just break through this 4hour


resistance and continue up, then I may


eventually move this 4hour support up to


that level.


Uh, but then again, I'll just kind of


watch and see what price does and of


course what that looks like on the 4hour


time frame. at the 4 hour time frame. If


I'm looking to the left and I don't


really see it lining up with


enough, you know, kind of rejections,


even looking far back to the left, then


that's where I will kind of decide,


okay, I'm going to I'm going to stay


with Thursday's low for now because that


Thursday low has more rejections or


bounces, you know, where I can kind of


see that price uh touch point more times


with Thursday's low than I do with say


like Friday's or today's or you know


Sunday like the last you know day to 3


days ago then then I'll just decide you


know what I'm just going to stay with


Thursday's low for now and you know


maybe add another caution line or


something like that. Um, a lot of times


if you're kind of questioning where to


put your caution line, um, this is where


I will either hop to my 15 minute. So,


if I see a lot of hesitation, maybe on


the 15minute time frame, I like right


here. I don't know if I'd necessarily


put one here cuz just this whole area


just looks


like crap. Like if it got down in here,


I don't know if if I would even set a


trade. I would want it to be either


below this support or above this


15minute area. But like right here,


if you see the crosshairs, you can kind


of see that that was like a a little


like kind of area that sticks out to me


as being a little bit of hesitation. And


then of course if you go down to the


five minute time frame,


you can sometimes see those areas


on there as well, you know, and maybe a


little bit better because you you will


get more candles that have kind of hit


that area being 5 minutes versus 15


minute, 1 hour, whatever time frame


you're looking at. you will see that


kind of bounce u you know or hesitation


maybe a little clearer. So, you know,


even right here,


you know, I know this is a lot of


consolidation in this area, but you


know, if you get your crosshairs


and line it up, you know, if you go to


the left and if you can kind of see it


lining up and your eyes kind of see


hesitation here,


little bit of hesitation there,


you know, if you just kind of feel like,


I don't know, I feel like there's a lot


of hesitation in that area, then just


put a caution line up and, you know, you


can always delete it. If price just


blows right through that and doesn't


really respect it or you don't get a


bounce off of it, then just delete it,


you know, cuz I know a lot of times if


price is consolidated, I guess too much


for me and I I feel like I am putting,


you know, a caution line here, a caution


line here, a caution, and it's just like


my chart looks like rainbow bright and


that almost is like too much for my


eyes. I like it just to be as clean as


possible. Then, you know, I might delete


it off or just


just know that my eyes will just kind of


see that hesitation. You know, if price


is getting to a certain level, I'll just


maybe like, you know, use my crosshairs


or just kind of look to the left and be


like, I don't know, there's a lot of


hesitation in that area. So, um you


know, if you need to put the line up and


just to help yourself be be aware of an


area.


Um and of course, same thing with


this. So, I might have to go. I know the


uh gold is pretty close or got pretty


close to the all-time high, but um


again, I will always


mark off if I can get on there.


I will always mark off this high.


So, we'll go ahead and put that on


there.


If I can type


Okay. So, of course, we don't have much


to work with with the talk cuz we're


we keep trying to make alltime highs


again.


But again,


with the breakout area on the bottom, I


would initially maybe go with this one


just cuz I see hesitation here and


hesitation right there.


And then if price were to come down and


break below this, then that's where I


will use my crosshairs again. And I


would probably stick with somewhere


around this area.


So that's just kind of how I, you know,


view. A lot of times you can shrink your


screen up. You know, sometimes I will


kind of like make my eyes blurry if I'm


like questioning something.


You know, I'm like, why am I not seeing


this as clear as I feel like I should?


um you know just shrink your screen down


as much as you can and look back to the


left uh as far as you can. A lot of


these support levels will will hold even


though they they may change as price


like kind of moves and you know like


price comes up and you know you're kind


of changing them around. you're putting


giving yourself a new uh 4 hour support


level, a new ceiling. uh your 15 minute


your 1 hour may change but if you go


back and look a lot of times these


levels will will hold and you know so it


may your colors may change I guess on


which time frame you're marking it off


you know with


you will see a lot of times you know


even going to like the higher time


frames


When we get to current price,


you know, you will see that a lot of


times


those areas will hold, you know, I mean,


even so that's November 13th. You can


see there was hesitation even back in


October. So, you know, you may kind of


be just switching your lines around. you


know each day they may be you know where


you previously previous previously haded


line and it may have been a 1 hour


support level and now it's a 4 hour you


know so just know that um you know those


areas can sometimes hold for for a long


time


yeah I agree yeah shrinking the screen


down to where almost like this like you


can't even hardly see the candles But I


feel like sometimes that will help you


see it and not not have all the noise of


the candles or the wicks. You know, like


this right here, like just shrinking it


down, you know, you can just see that


level held for a while. And you know,


and that's of course what I do. So just


each day whenever I come in I will


update


you know when market closes I'll update


with what it did throughout the day and


then throughout the night and in the


morning I'll kind of glance at it and


there's a lot of times that I really


don't need to adjust anything but if I


ever need to then I will. And sometimes


um also like if I'm going to adjust


these lines and I'm you know say I can


see my 4hour area pretty easily but then


if I get down to say this 1 hour or 15


and I'm seeing all these other lines


that I still have I will grab them and I


will get them and even if I put them


exactly in the same place I had them


before I will get them completely


completely out of my way and I will


start all over again. But so just, you


know, do whatever you need to do to kind


of make it easier for your eyes to see


those zones. And again, going down to


the 5 minute, if you adjust it a little


bit on that time frame, don't worry


about it. if you're doing it on the five


minute and you know questioning


you know what you marked up on the 4


hour because again the 4 hour can have


candles and wicks and going down to the


lower time frame sometime can just kind


of help you hone it in a little bit. So,


um, I hope that helped some of you guys


with, you know, maybe seeing those lines


a little bit easier or at least seeing


how how I look at my charts whenever I'm


marking them up and how I kind of


determine which which areas go in, you


know, at what price point. Um, but yeah,


so again, I know I always mark up my


charts, but I want you guys to also be


able to maybe maybe look at your charts


or even mark your charts up before I


mark mine up. And then whenever I upload


my uh my chart markups or my updated


ones,


then you can kind of compare with mine.


And even if I have one area as my 1 hour


resistance and you might have it as a


15minute, that's okay. I mean, we may be


a little bit kind of seeing the a


different thing. We're still seeing the


same zones, which is the most important


thing. You know, as long as we're seeing


that same area of hesitation, and we


just know to be cautious around it, then


that's fine. you know, my eyes may just


see,


you know, more kind of price touch on


the one hour versus the 15 minute. Um,


you know, but we may kind of have the


same lines, just different colors. So,


just know that that is okay if that


happens.


You know, just be aware


with no matter what area it is, what


color the line is, always be aware of


any area of hesitation. So, all right


guys. Well, again, I hope that helped.


If you have any more questions, uh even


whenever I do my markups, if you have


any questions, just post it on,


you know, either that chart or in the


chat and I can always check your lines


for you if you if you need me to. All


right, guys. Well, y'all have a great


day and I will see you all on tonight's


scalping call. All right. Bye.$video_07_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_07_summary$This is the practical walkthrough version of support and resistance. Shea marks up real charts step by step so you can see how these zones are used in live analysis, not just in theory.$video_07_summary$
      ELSE summary
    END
WHERE sort_order = 7
  AND title = $title_07$S&R In Practice$title_07$;

-- Backfill watch-page content for lesson 8: M's & W's / Chart Patterns
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_08_transcript$deeper into M's and W's. If you maybe


are having a hard time finding them, you


know, identifying why I even look at


them, I'm going to just kind of quickly


walk you through some examples and show


you, you know, just kind of how I use


them. Let me get a chart pulled up.


Okay. So,


in this one, I tried to find, you know,


a good example to show you guys. So,


you can kind of see and I'm going to


just kind of draw them on my chart and


then we'll kind of go through each one.


So, right here you can kind of see price


goes down, then we go up.


Then we go down again


and then we go up. So whenever I see


that and I see these two touches at the


bottom, price came down, failed to go


any further, came back up,


had a pullback, failed to go below this


level again. So sometimes you'll hear


people say double bottom, double top.


It's the same thing. So it's just the


bottom of my W. So whenever I see that,


I don't jump in at this first pullback.


I want to give it, you know, time to


take a breath, see if we get a second


pullback. That is whenever I will start


watching for my other confluences is


once I see this second touch then I know


that we are possibly going up into an


uptrend. So and you can kind of just


think if you see a W a double bottom


uptrend. So just think of this last leg.


Whatever direction this last leg is


going into, that's the direction you


want to be looking to get into. So this


one we're heading up into a bullish


trend. So you would want to possibly


look into getting into a buy. And then


let's see if we can find a


M.


kind of give you


an example of that as well.


I guess if we just look at the end of


this W. Bring that over a little bit.


So you can kind of see right here


whenever price came up didn't stay, you


know, in an uptrend for very long. Then


we had a pullback.


Then we came back. We retested,


failed to go any higher,


and then we came down.


The last leg


is pointing down. So, we would get into


a sell uh showing us that we're in a


bearish trend. So, you know, you can


kind of see if you draw that out, we


have a double top. So, price failed to


get above this ceiling level. You know,


you can think of this as a support, this


is a resistance. And so that that's


whenever you would whenever you see the


second touch and it failed to go higher.


That's whenever you want to start


looking for your confluences. Whether


it's the EMA cross the, you know, we're


looking at this one, a lower high, a


lower low,


you know, just look for whatever


confluences


you have as your rules, and that's where


you would want to start watching for


those. And so you can see with this M,


if we were watching after we saw this


second touch, then we automatically see


a lower low right there.


Our EMAs cross. So that's where we would


possibly, you know, if if that is enough


confluences for you where you would go


ahead and get into that trade. So I


don't just see that an M is forming and


immediately get into a cell. I will wait


until I see the confluences, you know,


line up with it as well.


And if you still have a hard time seeing


it


with the candles, you can always flip


over to the line chart.


Let me delete this. Let's get it out of


your way so you can see it better.


And if you need to kind of train your


eyes so you can see M


and then W. So if it it's a little bit


easier for you maybe to you know see it


without the candle noise then just


switch over to this line chart and


remember you can go in this drop down


and then just favorite the line chart


and click on that and let your eyes kind


of just get used to seeing the M's and


the W's. So I, you know, mostly I love


using M's and W's and it just is just


kind of another confirmation for me


that, you know, we are possibly getting


into a reversal and


I'm going to start looking for my other,


you know, confirmations at that time,


especially if we are at a support or


resistance level. and it just kind of


confirms to me what that I am seeing


maybe a reversal in the trend. So, um


they're pretty easy once you kind of


just get your eyes used to seeing them


and um you know,


just let me know if you have any


questions with them. Um, again, it's


just another tool if you don't like


looking at them or, you know, just don't


want to uh use them in your toolbox. Uh,


you don't have to, but you know, just if


you decide you want to try to use them,


but you're still a little bit unsure of


how to spot them, why we are looking at


them, or what to do once you do spot


them. I hope this video maybe just helps


you um you know with all of that. But


just let me know if you have any more


questions regarding it and we can kind


of touch on this as well in another


video. Okay. Thank you. Bye.$video_08_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_08_summary$You'll learn how to spot M and W patterns, why Shea pays attention to them, and how they fit into the bigger setup. The focus is on recognizing the pattern early and understanding what it suggests about price behavior.$video_08_summary$
      ELSE summary
    END
WHERE sort_order = 8
  AND title = $title_08$M's & W's / Chart Patterns$title_08$;

-- Backfill watch-page content for lesson 9: BOS vs CHOC
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_09_transcript$Hey everyone. In this video, I'm just


going to do kind of a quick one to go


over. You might hear me or somebody else


mention break of structure, change of


character. So, I just want to show you


kind of some examples and what each of


those mean.


So, if you hear me say that like one of


my confirmations, if I'm waiting to


decide if, you know, I think price is


going to continue up or if I start


seeing signs that maybe are telling me


that we, you know, might have a reversal


going on, I might say, you know, a


change of character or a break of


structure. So, I want to show you some


examples of each of those. So,


our change of character,


let me get it type this out.


Okay. So,


and I think I put this abbreviation in


the slang 101 tab, but change of


character. So it is


it will


So if we're in an uptrend


and


price starts


making


lower lows,


lower highs. So where it is


against


the current


direction.


Let me get this typed out and then I'll


show you some examples on the chart. And


then we have break of structure.


which is


let's see we'll go


uptrend


and if you start seeing


price


starts


making


higher highs,


higher lows.


So this would be a continuation


of current trend.


Okay. So now I'm going to show you just


a a few examples.


So change of character. So if you look


at this right here, you can see that we


are in an uptrend. You see a higher low


forming, higher highs forming


and then whenever you see if you just


draw


a line


at the previous low. So, if I was to


draw a line right there,


let me do it


little bit different color


just so your eyes don't see that and


think


um a support or resistance. Okay, so


we'll just put a a green since we're in


an uptrend. Okay. So whenever you see


price


did not make a higher low but instead


price came down


and started creating


a lower low.


So


it broke


this area right here. that it would be a


change of character, which to me is a


good indicator that I'm going to be


cautious. I would not just jump into a


buy if I see that because to me that's,


you know, a sign that we could possibly


be having a trend reversal. So, I'm


going to sit back and I'm going to kind


of watch it and see what price does from


there.


and then a break of structure.


Sometimes this can get


uh confusing. You'll hear other videos


or I have uh where I hear somebody call


a change of character a break of


structure. Uh but a break of structure


is a continuation.


So


right here you start seeing higher highs


but it's in a little bit of a


consolidation. So whenever you see this


accumulation and you know it's we're


going you know higher low and then a


lower low and then you know so it's just


the consolidation area. So, and it it's


almost like if you were to block that


area off. So, if you were to block off


based off of this high and you want it


to break out of that area and notify you


or get your attention, I will use that


as a confirmation that we are continuing


up. So once it breaks


out of this little boxed off area, then


that is a good sign for me to start


possibly looking into if we are going to


be, you know, continuing this uptrend


that I start seeing with these higher


highs and of course these higher lows.


So once you see that, that is considered


a break of structure. So just maybe


think of this consolidated area as a you


know your structure. So whenever it


breaks out then that is a good indicator


that I am going to start maybe looking


into all of my other confirmations on


possibly getting into a buy. So there


it's very simple. Um but you just might


hear


you know those different words uh break


of structure, change of character. So


whenever you hear that it it's not as


confusing as it may sound. Uh and then


as we go, we may add some other, you


know,


things that you can watch for that go


maybe


or pair well with breakup structure of


different things that you can watch for.


Uh but for now, I just wanted to show


you examples of what they look like and


of course what they are and the


difference in them. So, let me know if


you have any more questions about those


and we can, you know, dive a little bit


deeper into it. All right, I will see


you guys on the next video.$video_09_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_09_summary$This lesson breaks down the difference between break of structure and change of character. Shea shows what each one means on the chart and how they help confirm whether price is continuing or beginning to shift.$video_09_summary$
      ELSE summary
    END
WHERE sort_order = 9
  AND title = $title_09$BOS vs CHOC$title_09$;

-- Backfill watch-page content for lesson 10: High-Probability Entries
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_10_transcript$Okay. So, um I think in this call today,


I'm going to kind of just go over a what


I would consider a good trade versus a


not good trade and


maybe uh kind of train your eyes to


see the difference and um


and kind of go from there. So, let me


pull up my screen.


So, um I was trying to think of


something I could call them and for some


reason I at first went with um like


golden like I was thinking like my


golden retrievers. Uh but I couldn't


think of anything that was like, you


know, the golden would be like the good


trade and I was like straight alleycat


like I couldn't really like land on


something. So, um, so we just stuck with


a golden trade and fool's gold. So, um,


I'm going to kind of show you the


difference in,


you know, and it's mostly just your list


of confluences. So, um, of course, I


have these listed out right here.


support and resistance reaction 921 EMA


cross or W forming higher highs lower


lows whichever direction it's going a


break of structure change of character


and FVG getting filled. So, whichever


ones that you kind of want to stick


with, that you have, you know, luck


with, whatever it may be, um, have those


as like your talk maybe for and and try


to only take trades if those line up and


in whatever time frame you might be


choosing. So whether it's the 1 minute,


5 minute, 15 minute,


just stick with your confluences and you


know kind of really


practice your patience and not entering


into a a scalp unless you see all of you


know those confirmations. So um of


course this is kind of the order that I


look into. Um, I first want to look at


my support and uh resistance reaction.


Those are the areas I would prefer to


enter into a trade. Um, my 9 and 21 EMA


cross. I want to see that


MRW forming and then of course, you


know, higher highs, lower low or higher


lows if I'm in an uptrend. Um and then


from there you know I will still


consider like a break of structure if I


see it especially if it's you know say


in a little consolidated area then I


will see you know or want to see it come


up and break this structure. So,


um, and then of course I put fair fair


value gap on there, but


you all know that I don't always base a


trade, you know, just off that. But, but


I will peek. So,


okay. So, first I'm going to show you um


a fool's gold trade. So, it's where you


might see like some of your confluences


and you're almost like trying to


convince yourself that that it is a good


trade. It's going in a direction that


you might think it's going in based on


only maybe a couple of, you know, your


confirmations. Um, you know, or it's in


a messy structure. It's, you know, it


looks like this. It's a little


consolidated.


It doesn't have just pretty direction


that's maybe convincing you that it's


going in one direction or the other. Um,


and of course it's high risk, low


reward. So I'm going to go back here and


kind of pull up this one.


So this for instance, if you were to


maybe just be popping on the chart, you


know, of course this is at night, but um


if you were to see this and you know,


think, oh man, I'm going to get in this.


It's an uptrend. I see higher highs,


higher lows. Um and and you just get


into it almost just based off of that.


Um, you know, the EMA you can already


see is pretty far away. Um, but you


know, you may see this higher high and


you had a reaction off of, you know, a


15minute resistance area. So, you know,


if you were to immediately enter, say,


you know, right here, if we had this


little break of structure


and you just entered in and you really


don't take the time to think about the


bigger picture. So, you know, I put on


here that, you know, you had a reaction


off the 15minute time frame and that's


one good thing. You might have seen the


higher highs. That's another one. Um,


you know, break of structure, there's a


third one. Uh, but


even with those confluences being in


your favor,


you want to maybe just sit back and


think, you know, okay, we're really


close to a major support area. So, we


have this 4hour, you know, top


resistance that we're pretty close to.


So, we know we could get a reaction off


of that and it could potentially


reverse. So, just that alone would


maybe, you know, make you not want to uh


get in that. So, just kind of think


about that and


um you know, it's a little close to a


major support and resistance level. And


then of course you can see this lower


low that happened. So whenever you see


that that could be a sign of you know a


change of character. So it may be


starting to kind of uh signal that we


could be having a reverse. So, whenever


you see that, you know, maybe just wait,


you know, see if you're either going to


have a reaction off of this resistance


area,


um,


you know, and just kind of let more of


your confluences line up. So whether


it's a pullback and you want to wait and


see if your EMAs cross or you know just


continue to see these higher highs and


higher lows. So you know you can kind of


see this was a little risky low reward


also because where I would personally


place my stop loss would want to for


sure be below this low. Okay. So, if I


wanted my stop loss there where I kind


of felt a little bit safer, you know,


and I set my takerit at my 4hour


resistance, it's just there's not much


profit there. So, you know, also kind of


weighed that out.


Okay. So, now I want to show you kind of


more of a golden trade. So, you know,


this is the one of course where you want


to see more confluences. uh whichever


ones you go off of, make sure that you


can check them all off. You want to see,


you know, clean structure and of course


a smoother entry.


So, and of course, high probability and


lower stress. So, um I pulled up this


one down here.


So, you can kind of see we had a


reaction off of our 4hour support. Uh,


which, you know, is a very good uh


support area to get into.


uh even though I will get into them off


of my 1 hour and 15, but if I can ever


catch price and it's reacting off of a


4hour support, then that's even better


because obviously they hold more weight.


So, you know, if I see that it, you


know, came up and we had a, you know, a


retest of it. So, I had a, you know,


bounce off my support, major support.


Um, and then you know I'm starting to


see these higher highs come up and you


know of course I think I put this to get


in here but so you wouldn't have seen


this higher low but


um I also see a W forming.


Hold on. I got to get this out of the


way to get to my tool.


So I can see


this W


forming


and then of course we had a break of


structure. So whenever price broke above


these wicks,


then that would have been a good sign


for me to either enter or start watching


it. So


let me see if I can get back to it on


the one minute.


I know there's probably got to be a way


to bring it right back to where you


were.


Okay. So you can kind of see on the one


minute,


you know, even though this EMA crossed


right here,


I would have obviously waited until it


came up to this 4hour support. But you


can see that you know the EMA did cross


and then of course it broke the


structure on the 1 minute time frame


just shortly after it test you know went


above that uh 4hour support. So just


kind of depending on which time frame


you might be looking at um


you know with your confirmations.


Let me get this down where I can see it


again.


But okay, so for me, if I was to look at


this, it had enough of my confirmations


to go ahead and get me in the trade. And


even if I wanted to be safe and put my


stop loss below this area right here


and of course


I always usually put my takerit you know


at the next uh 4hour resistance if I


can. Um, so that would have been, you


know, a one to six, but I would have


been moving


my uh stop loss up with the one minute


fractals. So, I may have gotten stopped


out before it even got up to this area.


Um, but you can just kind of see how


much smoother, you know, that looks once


it kind of breaks out of this range


area. And you know, it just would make


me feel a little bit better versus this


one. You know, getting in almost at like


the tail end of the move is where I


would just want to make sure that, you


know, that I would be able to get more


profit than


than not. So,


so anyways, if you look at just kind of


the difference in those and kind of


train your eyes to, you know, maybe back


test a little bit and I know if you have


um trading view, you know, you can of


course do the replay mode and um


and then just kind of pick an area And


even if you go back to a certain day and


mark it off and then mark up your, you


know, support and resistance areas so


they match to that time frame and just


kind of look, you know, okay, I see this


is starting to give me confirmations.


Would I feel comfortable entering into


it? And, you know, mark it off. then hit


that replay mode and


just kind of continuously do that and


see if you know over time whenever you


see


your confirmations,


you know, if you can just pick them out


a little bit quicker and a little bit


easier and not get hung up so much on


just one or two and just immediate


immediately, you know, jump into it. So,


I just kind of want you guys to


create that muscle memory. Um, and then


of course, it doesn't always work out.


Like, if y'all were on the call this


morning,


you know, sometimes you see the


confirmations and,


you know,


I don't want to say, but just just


happens. I don't know. I It depends on


which pair you're trading. Also, um,


you know, NAS is definitely one that,


um,


you might want to wait a little bit


longer until you have some, you know,


more confirmations.


Um, also important to check news because


that can fluctuate it quite a bit. But


for the most part, you know, watch


around these resistance areas. you'll


see this accumulation


and then it'll kind of you know decide


which direction it wants to go and you


know that's where we just kind of


you know look at our confluences and


decide which direction we think it's


going to go in. Um so EMA cross I think


is a big one you know second to the uh


support and resistance. So


anyways, do you guys have any any


questions on that?


>> I have a question, Shay.


>> Okay.


um like on the one minute once it


crosses over your 4hour resistance once


it crosses over to the top do you wait


for a retest of that to see if it's


going to continue to go up or are you


okay with just the break of structure


and


you see what I'm saying like underneath


like underneath


>> are you talking about like they entered


the support


>> yeah like it like it tested It tested it


underneath the 4 hour, but once it


crossed over, do we need to wait for a


retest there, or are you okay with just


a break of structure and assume it's


going to go on up? I always like a


little bit of a retest. Uh, but


sometimes with like NAS especially, if


it goes above this support and breaks


structure, sometimes it can just have a


lot of momentum behind it to where you


might not get a pullback for a little


bit. Uh but yeah, definitely if you can


get a little pullback into it, then


that's even better, you know, cuz that


way you can see that it's coming up,


breaking structure, testing it, and then


coming back up. Um, you know, even like


two I would say, would be better, you


know, cuz that would kind of give you


your W. But, you know, if you can see a


W forming before that,


I'm okay with that. Uh, but,


you know, it's just kind of your risk


tolerance, I think, on, you know, if you


want to wait until you maybe get a


couple of retest, which, you know, you


can see if you waited,


you know, comes down. uh that one


doesn't quite, you know, come all the


way down, but it's still another


pullback. And, you know, if you feel


like maybe you want to wait until you


see a W forming


uh above the resistance, then you know,


you could still do that and then just


get in right here. But, but then, of


course, at that point,


it's by that 1 hour. So then I would


probably wait and see what it does at


that point. But but yeah, I think if I


see a W forming,


you know,


>> I just didn't know if the re if the


retest on the B uh underneath the 4 hour


and then it crossed over if that was if


that was good enough confir confirmation


or if we needed to wait on the top end


that but I see what you're saying with


the W.


>> Yeah. And I I don't think I necessarily


always do. It just maybe depends on,


you know, where this candle is that


breaks this structure where it's at, you


know, if it's fully like more above the


support. I you know if it's maybe I


don't know like say if this one right


here was above this wick I would maybe


wait and give it another candle to maybe


like fully break that structure. So you


know if I saw that above the support


then


that would be good enough for me. But


but maybe it's just because I


you know cuz it's NAS I feel like I I


know that pair. Uh but


you know I guess you never really know


know a pair uh obviously but um but yeah


I would just say and just depending on


of course what time frame you're on. So


you know if I jump to the five minute


You know, you can see whenever it broke


structure here,


you know, which would have been


more in that area,


you know, it's kind of the same thing.


You know, it came up and then we had a


retest and then, you know, depending on


where you whenever that happened of it


coming up and breaking this structure.


Um, you know, then I mean you still get


get in a pretty good spot with that


Nikki. Oh no, not me. Immediately


jumping in.


Yeah,


maybe not do that,


but I get that.


Let me go look at Bitcoin right now.


Of


course, my uh


my support and resistance is


not marked up on this one, but


boy, everything had a


crazy jump.


I'm not going to mark all this up. I'm


just kind of looking to see this


range.


Hey, I have a question.


>> Yes.


>> And I can't get my screen to share, so I


don't know. you just see a a black


screen. But anyways, um do you trade


from your phone or do you trade from


your computer? Typically,


>> I would say most of the time I probably


trade on my phone. Um, if I'm like in my


office and you know, I guess where I can


see it a little bit better, I'd probably


I guess prefer that just because like I


have a bigger screen over here. So if


I'm ever like back testing or anything


like that, I'll always want to do it on


my computer. But I do a lot of it from


my phone and maybe just so I don't feel


like I have to stay in my office is


maybe a big reason why. So I probably


have like carpal tunnel in my thumb from


it. But um but I've definitely gotten


into the habit of just trading on my


phone. I don't know. I guess I


>> I don't know why I do that. Maybe it


just makes me feel like it's a little


more passive.


Yeah, I guess I just asked because I'm


like, "Okay, I'm still new, so maybe I


need to like have a bigger screen so I


can like see it more clearly." I don't


know.


>> Are you Are you mostly doing it from


your computer right now or from


>> No, mostly from my phone, but I wondered


if it would help me. And I know some


people like use like an iPad if you have


that to where it's not like you're


necessarily lugging around a laptop or


whatever. Um, but of course the screen


is a little bit bigger than like your


phone. But I'd say it definitely takes


some time to like get used to it.


Sometimes if I'm trying to like maybe


move my stop loss up,


you know, or something like that, like


trail it manually. Um I feel like


sometimes it doesn't work that well on


my phone. But


I don't know what, you know, that most


might be like my phone cover or


something. I'm not sure. But um but I


think that's probably the only like


frustrating thing with my phone is if


I'm trying to like hurry up and like


adjust lines and it doesn't want to do


it fast enough. But but yeah, other than


that, um


I don't know. I've just think I've


traded with my phone for so long now


that it's just not that not that big of


a deal. it. But like I said, I'm sure my


hands and my eyes will not like it in a


few years. So sometimes if I'm in my


office, I will go ahead and like get in


the trade and then set alerts and and


then just peek at it, you know, on my


phone if my alert goes off.


Um, let me look at the chat. Uh sorry


already mentioned seeing these


confluences like the EMA cross MW change


character at higher time frame 5 minute


as well as the one minute would improve


probabilities too right yes I definitely


agree so a lot of times like you'll see


me you know like in the live I will pop


around like I'm kind of my chart goes


all over the place. Um, so I'll check


different time frames and of course I'll


like shrink my screen, enlarge it. Um,


but go into the different time frames if


especially if I'm ever uh, you know,


maybe like questioning


if I'm, you know, feel comfortable


enough just going off of my confluences


from the one minute. But if I'm ever


questioning it, then that's whenever


I'll usually hop over to the 5m minute


and maybe even the 15minut and you know


wait to see maybe like the EMA cross on


the 5m minute instead and not just base


it on the 1 minute. So yeah, I


definitely um agree Ellie if that's what


you were saying is you know just to kind


of compare and you know if you see all


of your you know confirmations on


multiple time frames then yeah that's


even even better.


I see that might be my problem too. I


might just have fat fingers and it's not


understanding where I'm wanting


uh where I'm wanting to adjust it to.


No, Tra, I haven't. So, those styllist


pins I have just never even used one.


But, um but I bet that would be a whole


lot better.


I'll have to look into that.


I think my husband uses one


maybe on his phone or like his phone had


like a, you know, a little thing where


like it popped out.


I have a hard time keeping up with my


phone. I can't imagine trying to keep up


with a stylus and my phone.


>> Yeah. And I think that's maybe why I


like the alerts so much is, you know, if


I'm at home or something and I don't


know, maybe sitting on the back porch


with my husband or whatever, and I I


just I don't feel like I have to really


do anything with my phone until my alert


goes off. And then if I'm at home, then,


you know, I could always just run in my


office and check it real quick. But um


but I do feel like it's getting,


you know, to the point to where I


probably need to slow down trading on my


chart.


>> Does your husband trade, too?


>> No, he doesn't. He has an account. Um we


set him up with all of that. Um and you


know, because whenever I was swing


trading, I always did the 4hour time


frame and I love that. I still do like


that time frame, but I don't don't


really trade it anymore. I pretty much


just scalp now. Um, but we were going to


have him, you know, do the higher time


frame and of course more just kind of


passive uh slow growth uh while I do the


scalping. But


I don't know his uh


he's just a busy body. So I think for


him if he's not at work, which


sometimes, you know, he's at work for a


couple of months at a time, then he's


home for a couple of months at a time.


But he just has to be like outside. So,


I think that's his biggest thing is


he just thinks, I don't know, I just


can't just sit and look at my phone or


be at a computer watching videos, you


know, stuff like that. He's got to be


like chopping down trees in the forest


or something. He's got to be doing


something.


But I think maybe uh later on if he ever


decides that, you know, he's ready to


give up on the oil field,


maybe he will at that time.


Okay. Fay. So, were you looking Oh, and


my lines are probably


not where they need to be


cuz I was looking at this and I was


like, "Oh, we're having a we're testing


that 4 hour support." But there's no


telling when that line was drawn.


Let me look at where this is real quick.


Might not be too far off.


So, I know the uh


I had this I think marked up.


Maybe it was in my top step.


And I know a lot of y'all were getting


in on that cell,


but maybe we're having a reaction and


going back up now.


Did you already get in this bay or did


you say you were just looking looking at


getting in it?


I mean, so far that looks really


>> I didn't get in it yet because I was


being patient and trying to take your


advice, but I was getting itchy.


>> I would be too. It looks It looks good


to me. Um, you know, of course this


4hour support. Um,


>> okay. The blue line.


>> Yeah, it's pretty close to that, but of


course that was Sunday. Now it looks


like it's going into consolidation. So


it's a good thing I didn't I took your


advice.


>> Yeah. I So maybe right here, Friday.


I don't know cuz I have this at Sunday,


but no, I'd probably leave it there


because it looks like it had some


reaction to this.


Yeah, I don't know. I mean, it


definitely looks good. I see, you know,


like a W on the five minute, but of


course with it being gold. Yeah,


>> I would


I don't know because by the time it


breaks this structure right here and of


course by then we may have a cross of


this it would be pretty close to you


know where I have that 4hour support. So


I would maybe wait and if you you know


>> wait till 4 hour. I don't know why I


don't have that marked off on I guess I


marked it off on something else.


probably trading view.


>> Yeah. And I would I'd maybe set an


alert, you know, around this area right


here and


and then kind of see what it does from


there.


>> Yeah, it may be it may be heading


heading back up after that drop this


morning.


>> But I do see what you're seeing.


>> It is kind of ranging right there. Yeah.


Oh, that's a good ways to go.


>> I know. I always


sometimes I definitely miss trading


gold.


>> Yeah, I think I would I think I would


wait on this one.


>> Okay, good advice.


>> Just to be safe.


Of


course, for me and gold, I'm like, let


me just wait until this 15 minute.


I want to be for sure. For sure.


All right, guys. Well, um, if y'all


don't have any more questions, I was


just going to pop back.


>> Hello, Shay.


>> Yes. Hey,


>> hi, it's Heather. I just have one


question about the break break of


structure.


>> Okay.


>> So, I was noticing on the NAS that you


just looked at the most recent structure


to break.


>> Is there do you only look at the most


recent one or like on this one?


>> This trade that you're looking at here.


>> Yeah.


>> You wouldn't look back another


structure.


I feel like I'm always waiting for the


the next structure to break, you know.


>> Yeah. No, on this right here, whenever


I'm looking um I usually try to go with


like the previous high. Um but of


course, like with NAS because it's just


a little um I don't know, more bipolar,


a little riskier I guess pair to trade.


Um, you know, I would like almost prefer


it to, you know, even come above like


these candles. Uh, but just it breaking


above this structure. Um, you know, so


which would be,


you know, once it broke above this


candle right here,


>> then that's usually enough confirmation


for me. Uh but you know, even if you


wanted to be a little more cautious and


just let it get completely out of this


zone, uh then you could do that. But


yeah, I don't usually go back too far. I


just want to look at the most recent uh


you know accumulation or you know this


range right here and


you know just kind of let it get out of


that


um most recent consolidated area.


>> Okay, great. Thank you. That helps.


>> You're welcome,


Jill. I have definitely done that.


Stretch your screen out. It's going


towards your stop loss. Make it look


further away.


That's funny.


Yes, Jackie. Let's see. Let me shrink


this down.


Are these the ones you're talking about?


>> Yes. Thank you.


>> Okay. You're welcome.


Yeah. And so if you guys want to um I


added a a space in the circle. Um and


I'll have to look. I think I named it um


something with homework. So if you


notice that trade lab. So, if you if you


want to if you kind of play around with


some charts and you're marking them up


and trying to find, you know, a a golden


trade versus a fool's gold, then, you


know, mark both of those up and maybe


list like your confluences, why you


would have taken it as a golden trade.


And then, you know, maybe if you found


another one that you would consider


fool's gold, you know, list out maybe


just how I did, you know, with this


little call out tool. um you know what


what made you initially think that it


would have been a good trade and then


versus kind of what you learned from it


based on what it did that ended up


turning it into a a not good trade and


if you want to you know mark those up


and then share them with the classroom.


So I know if you're in like trading view


and I know top is the same way but if


you click this little camera button you


can download the image. So,


um, if you want to upload those in that


section in the, uh, circle space and


that way maybe it can kind of help you


to get feedback from other people on,


you know, maybe they see something in


addition to what you saw. Um, you know,


or just kind of help maybe somebody else


out. Maybe somebody else will share a


screenshot that


you may have thought would have been a


good trade, but after they posted it and


you kind of see what you know what they


found after they dissected it, you know,


it may kind of be like, oh, you know


what, that wasn't wouldn't have been a


very good trade. So, um, that section is


there if you guys want to load up some


screenshots. And um and then I was going


to mention one more thing. Um


I know on Thursday,


sorry, Friday the 1st, um the trial


period is going to end and we're still


kind of um not 100% sure how that's


going to go. So, we're going to try to


play with it, but I just wanted to uh


kind of get with you guys ahead of time


and be patient with us. Um, I know one


thing is


if we wait and let it all transfer over


on its own, it's going to keep you in


the trial and and we can open up all


those spaces, but it's just going to be


um like two separate places. So, if you


guys know that you want to, you know,


stay and um just kind of upgrade your


subscription, then if you want to go


ahead and switch it yourself, and I know


in the um the circle space, let me get


that pulled up real quick.


Oh,


there it is.


um


over here.


Sorry, I got to remember where I put it.


Right here in this community connection.


This link right here. If you want to go


ahead and upgrade,


um you know, and maybe even like


Thursday the 31st, then that way we can


help you, you know, cancel the trial one


if we need to. Um,


but I think maybe that might be the


easiest way,


but if not, we'll still get you over


there. Um, you know, just be patient. If


it if something kind of goes a little


haywire and we're having to do them kind


of more manual, then


we'll get to everybody. Uh, we're going


to


get everybody's, you know, names first


just in case it completely kicks you


out. uh we'll get you back in there. I


promise. So, um just be patient. Um it's


going to be like a new learning curve


for us when the first happens, but but


after the first, we won't have to deal


with it anymore. So, um we'll figure it


out. But um but just wanted to throw


that out there to you guys that you know


I'll kind of put a little message out


before


just to remind you guys that if for some


reason can't have access we'll get you


back in and and I don't know it may


still let you DM me. Not sure how Circle


works, but if anything happens and


you're having any issues and you can't


get back into my space, um, see if you


can DM me still and and let me know um


you know that you are wanting to, you


know, upgrade but but maybe you just


like something happened. So, um, yeah,


either DM me if you get kicked out,


we'll get you back in, or if you're in,


you know, the circle still and just


having issues and not sure what to do,


then, um, you know, that's where you can


just maybe post in here and somebody


will get you fixed up. But anyways,


wanted to mention that. Just be patient


with us. And um Oh, okay. Julie was able


to DM. Okay, so that's good. Yeah. So,


for some reason it kicks you out while


you're, you know, transferring over um


just shoot me a DM and we'll get you


back in.


All right, guys. Well, I think that is


it for today. So, let me know if you


have any questions and of course if you


want to go find some, you know, charts


to mark up and post your golden trade


versus your fake gold and then we can


all kind of um give our opinions on it.


So, all right guys, well, I will see you


all this evening if you're jumping on to


the evening scalp with me and y'all have


a good day. Okay, bye.$video_10_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_10_summary$Shea compares clean entries with low-quality setups so you can stop chasing bad trades. The lesson focuses on what separates a strong opportunity from fool's gold and how to wait for the right confirmation.$video_10_summary$
      ELSE summary
    END
WHERE sort_order = 10
  AND title = $title_10$High-Probability Entries$title_10$;

-- Backfill watch-page content for lesson 11: EMA Crossings & Signals
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_11_transcript$Hey everyone. So, I'm going to just kind


of quickly uh talk about the EMAs and


their crossings and kind of just what I


look for as far as an an added


confluence before I get into a trade.


I'm going to show you some examples. So,


um on this chart for instance, you know,


I have the 9 and the 21 EMA. So, you can


see them over here in my indicators.


And if you haven't list them or added


them to your chart yet, you can just


come up here to indicators


and just


you can search just EMA and it'll bring


it up. This moving average exponential


and then you can just star it and that


way it'll just be over here. And then of


course, like I had kind of mentioned in


the um the indicator video, I have my 9


EMA black and my 21 EMA kind of an


orange color.


And so remember the 9 EMA is going to be


based off the previous nine candles. So,


it's going to kind of give an average of


the direction based off those previous


nine candles. And then, of course, as


price goes, it kind of, you know, the


furthest one away kind of fades out of


the average and it just a kind of a


continuation. Uh, so the same thing, the


21 EMA will be based off the previous 21


candles. So, uh, whenever I am watching


a chart and I'm trying to decide if I'm


going to jump into a scalp, whether it


be a buy or a sell, I of course will


look down at the


lower time frames.


And


I know I've touched on this before, but


just remember if the, you know, the


lower time frames, you're going to have


a lot more


up and down with the EMA just because


there's going to be a lot more candles.


So, um, I'll kind of show you on a


little bit of a higher time frame


just to cut out


some of the noise.


Okay. So, you can kind of see. Let me


get back. Show you. kind of a cleaner


example.


So if you want to trade on


whether it's the 15minut, the five


minute, the one minute,


any of them is fine. If you want to be


maybe a little more cautious with your


entry and just feel maybe a little bit


more secure then of course the 15minut


time frame it's going to take a lot more


you know price movement for it to cross


whereas the one minute time frame


you know you're going to maybe get that


cross a few candles


earlier. So say on this one you see this


cross maybe you get in right here. If


you're watching on say the nine or the


the 1 minute time frame you know it may


have crossed up here. So there's really


no difference. You may just get in a


little bit earlier but both of them are


correct. Uh don't think just because


you're getting in on the 15minute that


you are going to miss that opportunity.


Uh because you're not. If you, you know,


want to be a little more cautious and


that helps kind of eliminate some of


that stress and anxiety, then definitely


do that. So, what I want to watch for is


this nine


to cross this 21. So whenever I see that


cross happen no matter what time frame


I'm on then that is telling me that


there is a momentum change and we might


be changing direction. So


whenever I see that cross, that is when


I'm also checking if I'm having, you


know, lower lows,


possibly an M,


which you can


you can see we have a an M forming right


there.


So I see an M forming. I see a lower


low. I see my EMA crossing. So, all of


those would be good signs for me to just


kind of check off of my list. So,


you want to just kind of watch where


that's crossing at. And then same thing


of course right here you can kind of see


that it you know comes up to the 21 down


back up you know kind of flat lines and


if you look you can see this is just


kind of an area of accumulation. So you


know they're buyers and sellers are both


kind of you know trying to take over the


market. And then of course if you see


where we cross right here


if you're you know make sure to check


all of your other confluences. So, um,


we see an a W


forming.


And then, of course, like this right


here, because we were in this kind of


consolidation,


this second point is a little bit lower.


So, I still see a lower low, which is


where I would wait. Um, just because I


see this EMA cross, that would not give


me, you know, enough confirmation


unless uh I see


these starting to create higher highs.


So right here,


if you see that dotted line, whenever


this candle right here broke above


all of these right here, which is a


break of structure, then that's where I


would start getting a little interested


or, you know, maybe have an alarm set


right here to where it would, you know,


alarm me or notify me if it gets above


this level. And then at that point, I


would look, see that I'm getting some


higher highs and then kind of put all of


my confirmations together. And that


would tell me, okay, maybe we're


breaking out of this, you know, little


box and we are going to pick a


direction. So that's really just kind of


how I use the 9 and the 21 EMA. Um,


of course, just add it as another tool


in your toolbox and use it just to help


you kind of refine your entries and give


you a little more confirmation to


yourself that, you know, price is going


where I think it's going to go. And you


know, after a while, after you kind of


practice with all of these and choose,


you know, kind of decide which ones you


like and which ones you don't, the more


you practice, it may seem like a lot


right now. Like you might feel like you


have a checklist of 20 things just to


get into a scalp, but it's not. The more


you practice, the more you will just


immediately see it. So, you won't even


have to really think about it. You will


just, you know, your eyes will start


seeing the a W and M. Of course, you


will see the cross of the EMA and it'll


just all, you know, kind of just click


in your head and you'll see it pretty


quickly. So, um, just practice. If it


all kind of seems like a lot right now,


the the EMA is a great tool to kind of


show you the direction of the trend and


of course if we have more buyers or more


sellers in the market. So let me know if


you have any more questions or want me


to kind of clarify or show you anything


else as far as the EMA is concerned. But


just wanted to do a quick video to show


you what I use the 9 and the EMA for.


All right. Well, I will see you guys in


the next recording. Okay. Bye.$video_11_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_11_summary$This lesson shows how Shea uses EMA crossings as added confluence, not as a standalone signal. You'll learn what she looks for around the cross and how it helps confirm momentum and direction.$video_11_summary$
      ELSE summary
    END
WHERE sort_order = 11
  AND title = $title_11$EMA Crossings & Signals$title_11$;

-- Backfill watch-page content for lesson 12: Fair Value Gaps
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_12_transcript$Hi everyone. In this video, I want to


just go a little bit deeper into fair


value gaps and go over um a couple of


them. they I think it's important to


kind of understand the difference


between each one and how to use them to


your benefit and


also on the flip side not get trapped in


any of them. So, um first as far as what


a fair value gap is, it's of course a


three candle. Let me kind of


zoom in on one.


So you can see right here a fair value


gap. It'll consist of three candles. So


the gap between the first candle and the


third candle is what you would call your


gap. So, um, usually why they develop is


you have a lot of orders or I guess a


big rush of


buyers coming into the market. So,


whenever they come in really quickly,


it creates this gap. And


you want to kind of think of it as like


a magnet. So price usually wants to come


back into it to fill those orders. So if


you think of it like the big


institutions, the big banks,


all of those that place really big


orders. So whenever they come in and


they place you know this these large


number of orders


it creates this big rush in price. So


but all of their


orders don't get filled because price


moved so quickly. So, they still have


some of their orders in here that are


just waiting to get filled, which is in


turn what kind of creates this magnet to


come back down into this gap so


their orders can get filled. Basically,


like taking care of their unfinished


business. So, um maybe an easy way to


remember that is or kind of just what


creates it and why it comes back to that


area is if you kind of think of like a


really busy restaurant and say there's


only one cook and a table comes in and


it's got 500 people. So, he can't serve


all of those orders at once. So he kind


of just plates up a bunch of plates


quickly just to start getting them


moving and you know so it kind of


creates this


big move which is the gap and then of


course once all of that kind of calms


down then he will go back and finish the


rest of the orders. So that's


essentially the same thing that's


happening right here. It's just big


bank, you know, institutions, banks,


things like that


just putting in large amount of orders.


So


that kind of is what creates the fair


value gap, why it's created, and of


course why price usually always comes


back down to it like a magnet.


And over here we have what's called an


inverse fair value gap. So


this right here,


you want to be careful. This is what you


would not want to get trapped into. So


um it's always important to wait until


you have a reaction. you know, don't


just see that gap and immediately


strike and just go in, you know, to a


trade or whatever. Um, you want to make


sure that you still have all of your


other confirmations


that are telling you that you should be


getting into this trade. So um


uh the inverse fair value gap is


basically a leftover fair value gap


that's against the current trend. So um


what you will want to watch for is if it


does not get respected. So you can see


this fair value gap when price came down


and came in and filled those leftover


orders. price then returned in its


intended direction. So the intended


direction


is the co the direction of the candle


that created the gap. So it'll be your


middle candle. And if we're in an


uptrend


and that's where I see the gap, then I


will color this green just to let me


know if price comes into this, I know


that the intended direction that I want


to be looking for is a bullish trend. So


over here if you look at this inverse


fair value gap


it did not get respected. So whenever


price came up it didn't push price and


continue it


all the way down.


What it did instead was it came back up


and broke through


and then price,


you know, we kind of had this little


accumulation


and then price came down,


tapped into the fair value gap.


So this would have been a bearish fair


value gap because the middle candle was


sellers that created that. So this one


is colored red in my case because I have


red candles as my bearish direction and


green as my bullish. So whenever price


came down and tapped into this, it then


turned it into a bullish fair value gap


and it then push price up. So that is an


inverse fair value gap. So again, that's


where you want to


make sure all of your confluences are


there before you just immediately


jump into a trade, if you even choose to


trade fair value gaps.


And another one that I want to talk


about is this balanced price range. So


if you're ever kind of questioning


If you, you know, do I look at the


bullish one? Do I look at the bearish


one?


I see one, you know, kind of popping in


back to back, but they're opposite. And


you just aren't really sure which one to


take. It's not clear. So, you know, say


this one, that's a clear fair value gap.


Clear tap into it. you know, it's just


real clean looking. So, if you come over


here


and you see something like this.


So, I marked off some. And you can see


it's just, you know, are we going up?


And then up here, it's like, oh, are we


going down? This one is inside of the


other one that's inside of this. You


know, it just looks like a mess. So um


it is usually


seen


if there's like consolidation.


So it's where you know buyers and


sellers. So say initially we have this


one. So we have buyers in the market but


then almost immediately


sellers came in and reclaimed


you know


price essentially. So you kind of have


this battle ground of buyers and


sellers. And that's just where if you


start seeing that, just stay out of the


trade because it's usually


consolidation.


A lot of times whenever you see this,


you know, BPR,


it will end up most of the time


I'm just going to put a line right here


just to show you.


It will usually end up being a support


or resistance area because we have, you


know, a lot of accumulation


and


it's balancing out trying to decide if


there's going to be more buyers or


sellers in the market. So, of course,


you can see sellers took over this range


and we ended up going down. So,


a lot of times where you will see that


BPR, it will then


kind of turn into either a support or


resistance area. Um, okay. And another


thing I want to kind of


help you guys um decide when


you want to


strike and enter into a trade off of a


fair value gap versus when you might


want to wait. And let me go ahead and


I'll just type this out for you.


So


we'll do strike when


the fair value gap


aligns with market structure.


So you see higher highs,


lower lows, whatever direction you're


going.


So lower low would be with


bearish


If it forms I can't type today forms


near


a key support or resistance


area


higher time frame


fair value gap up.


If it's got a clean reaction,


which would be


a strong wick,


engulfing candle,


etc.


If you see the EMA,


the nine


and 21


cross


to confirm. Um,


I cannot type today.


So, you want to just kind of think of,


you know, having all of your other


confirmations.


You don't just want to go off of there


being a fair value gap.


Okay. So,


we want to wait


when


fair value gap is against


the current trend.


So for example,


if you see a


bearish fair value gap


in an uptrend,


you want to wait. So


that it could


be in


inverse fair value gap


meant to trap


sellers.


If there is no reaction


at the fair value gap yet,


you want to wait.


Or if it forms in the middle


of a choppy range.


That's where you want to


wait for a clean breakout.


So strike when


and wait.


Another thing is um time frame


alignment.


So, a lot of you will usually you see if


I'm talking about a fair value gap or


looking to see if I see one, I will


usually watch for them on the 15-minute


time frame. And that is because, of


course, I execute my scalps on the 1


minute time frame. So if you are wanting


to trade the 15minute time frame and


that is where you are wanting to say


execute your scalps then you can look


for your fair value gaps on the 4hour


time frame. So 4hour fair value gap


execute on the 15minut time frame


a 1 hour fair value gap is a 5minut time


frame execution


and then of course 15minut fair value


gap is a one minute execution. So it


tells you enough of the story that's not


too far away. So of course I would not


ever look for a fair value gap say on


the daily time frame if I am executing


my scalp on the 1 minute time frame.


There's just it's too far away. There is


going to be too much price movement in


between. So


the, you know, this time frame alignment


with the fair value gap, it kind of


gives you a


broader idea,


you know, the the zooming out uh to


where it kind of gives you that the


higher time frame bias, but not too far


away from the time frame that you are


wanting to execute your scalp on. So


just remember that whenever you're


marking your fair value gaps off and


you know what time frame you are wanting


to execute your scalp on uh you know


yeah what time frame you're wanting to


execute your trade on. So


that is basically


just some good things to keep in mind


whenever you're trading your fair value


gaps. Um, let me know if you have any


more questions and we can go over it


maybe in, you know, our live calls if we


need to. If if we need to, you know,


maybe mark some off if you're having


maybe some troubles identifying them, we


can go through and kind of find some,


you know, in a live market or on a live


call together. Okay, let me know if you


have any questions. Have a good day.


Bye.$video_12_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_12_summary$Shea goes deeper into fair value gaps, how they form, and how price tends to interact with them. You'll learn how to use them as context without getting trapped by every gap you see.$video_12_summary$
      ELSE summary
    END
WHERE sort_order = 12
  AND title = $title_12$Fair Value Gaps$title_12$;

-- Backfill watch-page content for lesson 13: Confluence vs Strategy
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_13_transcript$um on today's call. I just want to kind


of um and I'm going to mute everybody,


but you can come off mute if you if you


want to. Um so, I just want to kind of


go over I know there's been um like


we've gotten some DMs that enough to


where I feel like I needed to address it


at least to make sure that we're all on


the same page.


Um, I know


some of the messages that we got were


like people I know a couple of them


anyways had joined maybe like 2 3 weeks


ago. So, I feel like most everybody on


here that's been with me for a while


kind of already knows the difference


kind of between Confluence and mixing in


like a whole another strategy. But um


but I don't want there to be any like


confusion with that, especially if it is


somebody who has just started or if


they're trying to kind of figure out


which confluences work for them and


which ones they want to kind of stick


with. Um, I know if I don't know like


sometimes if you know you trade using


whatever your confluences are and maybe


you like uh get stopped out of a trade


or two, it can kind of um, you know,


make you second guess on if you should


follow your confluences anymore. And so


almost like that shiny object syndrome.


If you see somebody, you know, say hit a


take profit or whatever it might be and


you find out that they are doing


something different, you know, it could


cause you to kind of hop uh between


different things without giving any one


thing a good shot. Okay. You know, cuz I


I do fully believe that, you know, you


should give something a good I would say


minimum 2 weeks


before you really know if you want to


move on to something else and try


something different. Um cuz I won't lie


and say that I stick with my you know


same four confluences only and don't


veer off any from that because I do um


you know it's not necessarily that I use


different strategies but I think I will


sprinkle in different maybe indicators


or something like that that almost if


you know I want like extra confirmation


on okay this is doing what you know I


think it's doing what these confluences


are telling me to do


but I maybe just want like a little bit


of extra you know confirmation that that


it is doing you know whatever I think


it's going to do um you know so that's


okay if you want to maybe mix something


else in to just give you that extra,


you know, confirmation


uh that it's going to go in your


direction. But what I don't want to


happen and only because I know it can


really set you back if you, you know,


start kind of mixing in different things


or, you know, hopping from one thing to


another.


um


you know and not not just sticking with


what you know works. I mean you're going


to get stopped out. Trades are not going


to go your direction. You know they can


go you know your way for 10 trades and


then you might get stopped out five


trades. But it doesn't mean that your


confluences that you use don't work. Um


it's just sometimes, you know,


happens and trades go the wrong way. So


um I know it's kind of a tricky thing um


on what can just be a confluence and


what can be a complete different


strategy. So I just want to kind of talk


with you guys and make sure that we are


kind of all on the same page. I'm going


to share my screen just because I kind


of roughly typed out some things on the


chart. Um,


so


you know, of course, the confluences


that I use, you know, y'all know support


and resistance, breaker structure,


um, 921 EMA cross, MW pattern, and then


of course, you know, higher highs,


higher lows.


you know, things like that. Um, so I


will kind of mix some of these up. Um,


of course, what works for me doesn't


necessarily work for, you know, the next


person. And obviously that's okay. Um,


and I'm not saying


only use the confluences I give you.


everything else is wrong or um you know,


I want y'all to find what works for you


guys. Um but I just want to make sure


that y'all


whatever you try,


you stick with it and give it a real


shot before you know if it's not going


to work or not.


Um, so I wanted to give some examples


and if any of y'all have any that maybe


I don't use or um, you know that you


might also think is just kind of an


extra confluence but not necessarily a


different strategy. Um, definitely let


me know either in here you can come off


mute if you want to DM me you can. um


you know cuz not everything is a


complete different strategy.


Uh you know so I know as far as like


different indicators um there is um you


know like the trading sessions where it


will mark off the highs and lows of each


uh session. I think that's great. Um, I


will even like if I'm on my trading


view, I will even flip over to that


sometimes even if I'm kind of like


questioning, you know, maybe a support


and resistance area, you know, I'm like,


"Okay, well, let me go see what the


London high was, you know, or something


like that." Uh, so you can, you know,


add the indicator and then just do like


the little eyeball thing if you, you


know, want to maybe hide it and just


turn it on whenever you want that extra


confirmation. Um, you know, so like


something like that is great. That is


not a complete different strategy. It's


just like an extra confirmation. So, um


you know like trading sessions um and I


might also have some of these names


wrong but there's also uh like smart


money concepts um I know it will mark


off like break of structure change of


character


um you know so if you don't want to


maybe mark that off yourself or whatever


same with like fair value gap I know


there's a um an indicator that like will


mark off like fair value gaps. I think


the only reason I don't use it is


I'm pretty sure it will mark off every


fair value gap and


and I just feel like I um you know for


one don't really


use fair value gaps as one of my main


confluences.


But I feel like it well it just marks


off a lot of them that maybe I would not


consider. But again, if if you want to


use that, that's, you know, perfectly


fine. I don't think that would cause any


confusion.


Same with like hyenashi candles. I know


those can be great, you know, to kind of


an extra confirmation of maybe when to


get out of a trade. Um, you know, and


then there's another uh volume I think


some use. Um, I've never really used it,


but I think it's the one that shows like


the graph on the bottom and it just


shows like the volume of like buyers and


sellers if I'm not mistaken. Um, you


know, something like that I think would,


you know, be good as like just an extra


confirmation


of, okay, you're seeing what you think


you're seeing. you know, here's one more


thing to just kind of help you out a


little bit. Um, so I don't want


um, you know, and I guess I don't want


to word it as I don't want you guys to


because obviously I don't want um, you


know, it to seem like it's coming from


like an ego or anything like that. I


just don't want there to


be any confusion. Um because I think


whenever somebody feels like it's a


complete different strategy that's being


discussed, they either um you know have


DM'd me. I've gotten some that are


irritated because they feel like,


you know, I didn't go over that in my


strategy video or almost like I'm


holding back and not, you know, not


teaching them the full strategy. Um, and


so, of course, I've gotten those


messages. Um, and then some that will if


they see something is working for


somebody else and it is what I would


kind of consider a different strategy,


they will almost push everything aside


that they have been learning and trying


to almost hone in


their set of confluences that you know


work for them. they will almost push all


of that aside and only use the one


thing, you know, that maybe they just


read in a chat or something and you


know, so they for one don't fully


understand


how to do it. Um, and


you know, almost


well, they'll just a lot of times do it


wrong. uh or they will end up losing a


trade because they may maybe don't


understand fully what the strategy was.


Um and then if they end up losing their


trades, then that can kind of bring


their um you know, their mindset back a


few steps. uh because then they're


really like great you know the first one


I got stopped out on now I tried this


new thing I got stopped out of this and


you know I just you know trading is not


for me and I just don't know what I'm


doing and you know it can really bring


somebody in like a downward spiral. So


um I think that's where I just want to


kind of bring caution to


doing that. Um, you know, cuz I'm all


for try different things, find what


works for you, but


stick with it. You know, give it a good


chance before you move on to the next


thing. and


you know so I think whenever things are


talked about in the in the chat and I


know that that there's no harm meant in


doing so it's just hey this what you


know works for me it's great I love it


you know if anybody else wants to try it


out


so I just maybe on the flip side don't


want anybody in here that whether you're


you you know, new to trading or new to


maybe my group. If you ever do see


conversations happening, whether it be


an indicator or maybe just a different


confluence that somebody else uses, just


take it at face value.


you know, you can kind of implement it


yourself if you want to as just kind of


a an extra confirmation, but I don't


want you to throw away everything that


maybe has worked for you and you know


that you've really put in a lot of work


to learn. Um, you know, I don't want you


to push all of that aside and only use a


certain indicator or certain confluence


that maybe somebody else put into the


chat. Um,


you know,


and just remember that the confluences


should give your core setup more


confidence, not add confusion. Um and if


it's replacing the strategy that even


you know that you came here to learn


with me um you know if it's replacing


that whole strategy


um you know it's not a confluence it's a


it's a detour. So um you know I fully


believe that if you can find one maybe


two pairs I know you know some maybe


flip between one and two and and that's


fine. Uh, but I would say maybe no more


than maybe three pairs. Um, you know,


one strategy and try to stick with one


time frame. And I feel like if you do


that um you know for two weeks at a time


if you want to


and you will see that for me anyways it


really like cuts down on anxiety. you


know, if I'm flipping around, you know,


with every, you know, time frame and,


you know, excuse me, this trade I'm


going to trade on the one minute and the


next one I'm going to, you know, jump to


the 15 minute and the next one I'm going


to jump to the hour and, you know, to


where you never really learn or get


comfortable with one time frame. It can


cause a lot of anxiety. Um, or like I


said, it does with me anyways. So I


think for me, you know, I execute on the


same time frame. Um,


you know, for the most part, I just


watch NAS and I pretty much stick with


my same confluences all the time. Um,


you know, again, I will sprinkle in some


different uh confluences or indicators,


you know, if maybe I'm questioning


something, but the core of what I do


stays the same. And I think that's


really the only way to know what works


for you and what doesn't. um fair value


gaps. They are not a strong suit of


mine. I've tried to, you know, add those


in as kind of one of my higher up


influences


and


I don't know, for some reason I was


either secondguing them too much or, you


know, if I was maybe holding too much


weight with say, I don't know, a support


or resistance area, but then I would see


this fair value gap that, you know, was


kind of coming in between a support and


resistance. It would almost just make me


secondguess


all of it. And


so I kind of just slowly had to, you


know, get rid of this one and, you know,


just stick with this and, you know, so


over time I just kind of came up, you


know, with what I felt were like my top


probably four confluences to where I


will always stick with those, you know,


if they are there and I'm either, you


know, still questioning it or just


wanting that extra. Then, you know,


maybe I'll look at the trading sessions


indicator and, you know, if it confirms


what my um what my like say four


confluences were already telling me,


then great. You know, that just gives me


like more confidence in the trade that


I'm taking. So, um, you know, I know as


far as like, um,


you know, some may only take a trade if


price has come back into the 21 EMA.


And, you know, that's like the only


thing that they use to get into a trade.


They don't really look at anything else.


um which is obviously fine if you know


that's what you use but to me that's a


different strategy


only because I don't go over that in you


know in the SLS strategy. So I feel like


if that is the only


um kind of confluence or confirmation


that you might be looking at then I


would consider that like a different


strategy and not just an extra


confirmation. So um you know if somebody


is new or if they have only learned u


you know what they've learned in here


and they see other talk about the EMAs


other than you know the 9 and the 21


crossing then


it will just kind of add some confusion


because


they didn't learn it. they didn't watch


any of my videos that talked about it.


And so it just kind of puts that doubt


in their head of like, am I doing


something wrong? Because I don't even


have that EMA on my screen, you know?


Um, I know whenever I like first started


coaching,


um, I was doing like the 50 and the 200


EMA and I mostly was using it kind of


like an extra confirmation


uh because I know not everybody scalps


on like the one or the five minute time


frame. So, um, you know, just as like an


I don't know, an extra confirmation just


to make somebody feel a little more


confident in their trade. Um, I just


used it as on say like the 4hour time


frame or like the higher like way higher


time frames. If those EMAs crossed on


the higher time frame, it was usually a


pretty good indication that, you know,


we were getting a trend reversal.


But that was another one of those things


I kind of dropped off of, you know, my


list only because there was a lot of


confusion. Um I got had gotten so many


messages and I don't know if it was


because on the lower time frames of


course I look at the smaller ones the 9


and the 21 EMA cross and so whenever


they would hear the 200 and the 50 they


were trying to implement that on the


lower time frames and it just didn't


work the same way


you know that it worked on the higher


time frames as far as the way I was


teaching it. So that was one of those


things that hey, we tried it. It didn't


work out. And so I just kind of slowly


faded it out. But you know, so now if


somebody hears that and they maybe have


just joined with me not too long ago,


I don't even mention that anywhere in my


strategy videos. So they, you know, are


pretty confused by that. and you know


they're like okay do I am I now watching


for the you know the 250 EMA to cross on


the 1 minute and so they'll just kind of


start mixing things up that that don't


need to be mixed up because it what


works over here does not work over here.


So I think that's where you know it can


just be a slippery slope. Um, I never


want y'all to feel like you got to watch


what you say in here. I never want y'all


to feel like you can't help anybody out.


You know, if if something works for you,


great. I love it. It may even be


something that I may have never looked


at and, you know, I may hop over to my


practice account and like, hey, let me,


you know, let me check this out and see


if maybe I like that. um you know it's


just like a an extra confluence or


whatever. But


um but not everybody will do that. Some


people will see that somebody hit a


takerit using something different and


they will go straight to their live


account or straight to their challenge


account and go all in, you know, cuz


they're like, "Hey, they they hit a take


profit. What if I add this? you know,


I'm going to hit a takeprofit also. So,


that's where it can just start getting a


little bit dangerous. Um, and


I just went blank.


Um, but yeah, so I just I want to make


sure that that we are all on the same


page whenever I make, you know, posts


like that that y'all know that it it's


coming from a good place. Um, I just


want to make sure that everybody,


you know, is just careful, you know,


that they give a something, whatever it


is, a good shot. And, you know, and that


you also know if you see somebody


talking about something that,


you know, don't drop everything that


that you have been doing and only do


this one thing. So, um,


just kind of I guess take it all with a


grain of salt. If it works, amazing.


But just I just know how dangerous it


can be for the mindset, you know, and,


you know, especially if somebody has


been on a losing streak. um whether


they've, you know, recently lost their


combine or got stopped out of a trade or


whatever the situation may be. We all


know, we've all been there. Um, you


know, it's almost the same place that


like revenge trading comes in, you know,


it's like I lost a trade, I need to make


it back.


you know, you almost start getting a


little desperate and um you know, you


just want to try


anything else than what you have been


doing. And obviously, if we all see


somebody win, it's amazing. And we, you


know, we want to try what they're


trying. Nothing wrong with that. Um like


I said, I even do it. So, um, but


you know, I just don't want it to take


away any progress that you maybe have


made so far. Um,


you know, just understand that you're


going to lose trades


um, no matter what strategy you're


doing. So just find something that works


for you and really stick with that. Um


you know and just if you want add things


in to kind of go with the core of what


you do. So, um there was something else


I was going to mention and I of course


went completely blank, but um


I don't know. Is there anybody that


wants to say anything or have any


questions like regarding any of that? Um


you know, I want y'all to still be able


to of course share your charts and and


all of that stuff. Um, even your wins,


you know, if you hit a takerit and it


was like, hey, I wasn't even, you know,


I wasn't even doing this. I was doing


this or I was trying this out and it


worked and I hit a take profit. Um,


still share your wins. I mean, don't


feel like you can't um if it if it is


not, you know, even if it's not any part


of the SLS strategy, um I still want


y'all to feel like y'all can share your


wins with us cuz we want to celebrate a


win no matter what, no matter how you


got it. Um, just, you know, just know


that people are probably going to come


and start asking you a million


questions.


Hey, what are you doing? You know, can


you teach me how to do that? Um, and


just know that it


they either understand the risk to it or


they don't. and not knowing which place


they are coming from, where their


mindset is, how long they've been


trading. I mean, you just don't know all


of those answers. So just be cautious


when answering that, you know, kind of


view it from all points of, you know, it


could really help somebody who's been


trading a long time and, you know, it's


just that extra little edge that maybe


they need um, you know, to give them


that confirmation


so they don't second guess themselves.


or of course it could do the opposite


and it could, you know, really


just kind of um get rid of all progress


that they've been working on. So,


um let me check the chat real quick.


Um I agree with everything you said.


It's important to stay focused. I've


done way too much strategy hopping in


the past and it never worked out for me.


Yes, I I agree. And I think that was um


you know I have learned a lot of


strategies over the past twoish years


since I've started trading. And I know


for me that was always a um


almost an irritant


uh with that was like oh just stay on


one strategy. Um I ended up making it


work for me because I just kind of same


thing I kind of picked and chose what


worked for me and what didn't. Um and


you know of course in the end kind of


came up with the core strategy that that


has


um benefited me more than it's failed


me. So I know I'm going to lose trades


doing it the way that I do it. But I


feel like in the end I've made more


progress sticking with my rules than,


you know, some Tik Tok video that I see


of, you know, some guy doing something


on his screen. Um,


you know,


I just probably wouldn't do very well


with


completely throwing mine to the side and


just sticking with what they, you know,


might be showing. Um, and especially a


lot of the ones online, it's like, you


know,


they'll usually follow it up with that


they made a lot of money doing whatever


it is that they're doing. And um yeah,


so some people may want to definitely


chase that assuming they're going to do


the same.


Um I agree with everything that has been


said moving forward. Are we still doing


the prop firm together? Uh yes,


definitely we definitely are. Um, and


I mean I know that that's kind of um,


you know,


changed how we've been doing that, I


guess, just because, um, we don't want


to get in trouble with like copy


trading. But that's where, you know,


another thing with us kind of doing the


challenge together. Um, you know, I know


every morning I will do my um, you know,


my bias for NAS and only because that's


really the only one that I follow along


with or trade. So, you know, I'll do my


bias on NAS every morning. Um if maybe


gold is your pair or


you know crypto whatever maybe your pair


is um you know definitely feel more than


welcome to hop in um


let's see down here in prop firm


right here a daily bias um you know cuz


like I said I just do one on NAS, but if


there's a pair that maybe you follow


along with and you want to throw out


your daily bias on there, um definitely


feel free to or if there's maybe one


that you're looking at and you're


curious what what I think um it might do


kind of I don't know depending on what


um like where it's at as far as support


and resistance or whatever then you know


just holler or tag me maybe in in here


or I don't know somewhere just tag me


and you know ask me to look at a chart


and I can definitely do that. I can


throw, you know, another bias out here


if you want, but um but yeah, so just um


you know, I think doing the daily bias


so everybody will at least kind of know


what what everybody else is looking at,


looking for, waiting for,


you know, like I won't look to get in


this trade unless it say crosses my


4hour, you know, support or crosses my


one hour, you know, or something like


that. And that way we can all maybe look


at different charts and know that we're


kind of seeing what everybody else is


seeing and um


you know, and kind of get away from


hopefully getting in trouble with like


coffee trading because we're not calling


out any trades. It's just hey, this is


my opinion, what I'm looking at.


everybody else wants to look at it too,


you can. Um, so we'll still do that. Um,


it's another reason why I kind of wanted


to make sure that we're all on the same


page, you know, with all the um,


confluences, indicators, completely


different strategy,


you know, early on. Because if say


you know you're doing the challenge


together and you post a picture


you know in maybe what you're waiting


for you know in your daily bias and say


if you know


I put in my daily bias that um


trying to even think of something like


I'm going to wait until the and I


probably have this all wrong because


know I don't know how they do it but you


know I'm going to wait for the VWOP to


get it 350


you know y'all be like what the is she


talking about you know because I don't


teach on that obviously I proved a point


I don't know nothing about it but um you


know but if I was to put that or if


anybody else was to say put that


nobody would be able to follow along


along with that unless they also do that


and they would know exactly what they're


looking for. So, um you know that's


another one where you know definitely as


far as the um the challenge goes if


we're all kind of at least sticking with


the core thing. So if somebody, you


know, is like, hey, I took this trade


on, you know, gold today,


people can, you know, for the most part,


go back and look at that gold chart and


see exactly why they probably took it,


you know. Oh, okay. Well, I see what


they're seeing. It, you know, it had a


reaction off the 1 hour, you know,


support. I saw that W. The EMAs crossed.


I can see why they got into a buy, you


know, and it just kind of even if


somebody didn't get in the trade for


whatever reason, you know, working,


wasn't looking at the charts, wasn't the


pair that they normally trade,


it is almost like a good confident


booster to even be able to go back and


look at it and


see somebody else's chart, but know that


you agree with them and you see what


they saw and you know so you can just


even think to yourself okay I would have


gotten into this also um if I would have


been looking at the charts you know


because I saw exactly what what they


were seeing so I think that's another um


you know reason kind of going forward


with the challenge is you know that it


can help somebody else Um, you know,


just see what see what you are seeing.


Um,


hold on just a second. I'm just going to


read the chat real quick.


>> I've got a question.


>> Yes, go ahead.


So, I I I love the 921,


you know, for shortterm scalping. I've


used it for for years, but and I'm I've


been I wanted to learn these prop firms


like I think I mentioned a couple weeks


ago.


I joined just because y'all were doing


the prop firm stuff and doing my


research is like I even put in the


whatever post I said now that I've


researched it I'm even more confused.


They're crazy. Mhm.


>> But my question is like this morning


when in in Topstep X, I think I heard


you mention


that you were in uh practice trading,


right? Not


on the on the screen this morning.


>> Uh yes. Yeah. just whenever I'm doing


the live trading um I do hop on the


practice account just because I don't


want us to get in trouble for copy


trading. So my question would be because


I'm asking because I have no idea


if you are in a live I'm going to call


it a live trading account within Topstep


is the data different right are they two


different feeds?


>> That's my first question. Um, no. So,


real quick to answer that, like the


practice account and then if I were to


say hop over to um a combine or an


express account um


>> price would the chart looks exactly the


same


>> which both means that they're I just use


the word live that it's


combine. What what are the two


differences? Just different type of what


you purchased.


>> Well, no. So, whenever you first


purchase a challenge account and you're,


you know, trying to like pass the


challenge, they call it a combine.


>> I got it. I got it.


>> And then once you pass the combine,


um then you get moved to what's called


an express. So, it's kind of like um


in the past it's kind of like what would


be considered a funded account. So, you


know, the Express account you're able to


like make withdrawals out of um you


know, there's rules and stuff that I


>> Yeah. Yeah. Yeah. you know, but but


yeah, that's basically like their


version of kind of like funded without


>> But you but you agree that all the if


you went from account to account that


the data feed as far as price is the


same.


Um it is now I don't know about like


their actual like if you get called up


to be you know live what they consider


live live um I don't know about that


chart


>> that is a real word in prop for I heard


somebody say that you have to be invited


or something


>> yeah so the group yeah


>> a top steps version of what they call


live um you either get invited up, you


know, to be in a live account um or and


I'd have to go back. I know I went over


it in one of my uh calls with prop


firms, but um or if you do like 30 I


can't remember and I might be getting it


wrong, but it's either 30 withdrawals


out of your Express or 30 days


profitable up to 30 days. I've heard


that mentioned now. It's kind of, you


know, all over the social media networks


and people promoting them and


>> I remember someone saying, "Yeah, you


got to be invited." And


>> and then there's all these prop firms


that are overseas and not in the US. And


>> yeah. Yeah. There's definitely a lot of


uh prop firms out there. Um, and right


now I'm also testing um testing one out


for a takeprofit trader. Um, and then


Alpha Capital. But, um, just to kind of


see what what I think of them, how I


like them. Um,


>> but where I'm where I'm at with prop


firms is whether


is it worth it to do a prop firm or just


trade real money. That's where I'm at.


So, I'm just evaluating, watching, and


seeing what's out there. And um


you know, I unfortunately I don't trust


the TR prop firms too much. That's the


problem.


>> It's


>> No, I agree. So I think um you know cuz


I traded with like my own money uh


before I you know even looked into prop


firms but um I kind of see uh the pros


and cons with them. So, as far as like a


prof firm goes, like say for this one,


the Topstep when they had their promo


code, um, you know, for a $50,000


account, you could get one for like $36.


So, to, you know, potentially have I


think $50,000 for $30,


>> I think, is good. you know, there's


obviously like the risk


um you know, with they could shut you


down or whatever, but um but I think if


you have a live account alongside maybe


a prop firm, um you know, anytime you


make withdrawals from the prop firm,


maybe throw it into your live and keep


compounding it. um you know so I think


it is good to kind of build both of them


together and not just rely on maybe one


or the other. Um but but I do think


>> you have you have monthly fees and you


have to pass it and then you have to uh


do a setup fee and


>> yeah


question is whether


>> step


>> manipulating the data


which is going to force you just to you


know basically they're going to force


you to make payments for six months


before you ever


get get a payout. out.


>> Yeah.


>> Yeah. I mean, and of course, just


depending on which one, you know, which


one you go with, like I know with Top


Step, once you pass the challenge, you


don't get charged that monthly fee.


That's only like while you're trying to


pass it. And of course, you can cancel


it anytime you want.


>> Um, but you know, it's just it is it's


all preference. Um there there are risks


to it, which is kind of why I always say


before you do, you know, go with a prop


firm if you choose to definitely do your


own research and find


>> Yeah. Remember I put one in the group I


found was 16 like $16 for 90% off and


and they were pretty well respected, you


know. I can't remember the name. I've


heard it.


>> Yeah, there's a few of them that do like


I know um Apex I think. I don't know any


like I've never traded with them, but I


know every once in a while they'll do


like you know 90% off and um the one


that I got with a take profit trader. Um


it's um


like no activation fee trying to


remember. And I think like maybe 40% off


for like life. As long as I, you know,


if I want to keep getting new ones. Um,


you know, once you pass,


there's not that activation fee, you


know, like Topep has. Um, but I think


there's definitely pros and cons with


every single one of them. you know, if


you want to trade futures, if you want


to trade forex.


>> This is where I'm confused and and I I


don't want to you I don't want to take


over the hour or 30 minutes, but I'm


just deciding whether I want to play


with prop firms or real money. And one


of the reasons I think a lot of people


say don't trade the microe minis is


because typically the mark you basically


have to have 3,600 bucks to open the


trade, right?


Um, are you talking about with a with


live money with


>> correct?


>> Yeah, I know there's different um I


don't know if I've ever put it in the


circle, but if not, I'll um I'll put it


in there where it has like a breakdown


of how much each, you know, say contract


is a micro contract.


>> Yeah. In TW it's in it's $3,600.


to open one trade.


But I found a broker called AMP in


Chicago and they're US brokerage.


They're not I wouldn't send my money


overseas for anything. Um but you can


open a trade on microe mini NASDAQ for


as little as $100


and it's an 80 80 uh 8020 margin,


>> right? Literally, you can open a trade


for $100


and if you're a swing trader, you know,


it could turn into $10,000. But you,


>> right,


>> you only


if the trade goes against you 80% or 80


bucks, same thing. They will


automatically close the trade and take


your 100 bucks.


>> See what I'm getting at?


>> Yeah.


>> So, I I'm just evaluating that. Hey, and


it all boils down to money, but if for


$100,


uh, you can open the trade and as long


as you don't hit the margin, which is


your stop loss, right?


>> Right.


>> You know, if you set it there, you know,


that trade just stays open. Um, except


that after


uh 4:00,


you know, when the shutdown is for the


hour,


>> Yeah. you actually have to have the it's


only intraday margin. So if you kept


that trade open


over that hour, you would have to have


that $3,600


in the account positive


>> to stay in the trade for the it to


reopen back up, you know, after the one


hour shutdown.


So, basically, you could turn a $100.


You're going to still risk that 3,600


over the hour, but during the day, you


only need the $100 to open that trade on


a hypothetically $36,000


leveraged


uh e- mini NASDAQ contract.


So, basically what they're doing is


almost like a prop firm with real money.


It's just reverse,


>> right?


>> And the and their fee is a$124


a round trip.


Schwab is


um with the KBY exchange fee basically


525


where amp may be around like a $1.50


round trip. So every time you hit the


button in Schwab to get in and get out,


you're paying 550.


Yeah, ma'am. Which


>> that can definitely add up.


>> Yeah. Yeah. Yeah. If you're a hyper


trader, right?


>> Right. Yeah.


>> Like I said, if you're a scalping, you


know, you have to calculate the fees


just to scalp. So, it's kind of like a


small swing trade. But AMP's fees are a


lot cheaper.


Schwab says they'll get the fees down if


you trade, but you're going to have to


show a trade history, but fees are


negotiated.


>> So once you have a history and they look


at your history, they'll reduce the


fees. And what I hear in TWAB, you can


get down to about $3


round trip.


>> Yeah. Well, yeah. That's why I


definitely and I know um I know there's


a lot of us in here right now that are


doing, you know, the top step. Um but


but there's a lot of, you know, that are


doing other prop firms. Um you know,


>> I just don't understand why the the


price is different in TopE than the real


market.


>> Yeah. I'm I'm not sure I'm not sure why


that's so different


>> that we're not that's and that's my


problem with the prop firm. I'm not


putting them down or anything. I'm just


trying to understand it.


>> Yeah. I mean, and like you know, like I


was saying earlier, I think definitely


if you know, if you if you don't need


the prop firms, you know, and um kind of


have enough to where you can trade


without them, I think that's great. Um,


but but I do think it it can be good,


you know, as long as obviously you're


not spending $10,000 trying to pass a


prop firm and you're not passing it,


then probably doesn't weigh out very


good. it. Um, but I think if you know,


for one, I think trading with a prop


firm, it can almost like give you that


good um, you know,


muscle memory of um,


>> yeah, you're basically paper


>> trading with your rules.


>> You're paper trading.


>> Definitely. Yeah. Yeah. Until you pass


it. Yeah. It's all demo, you know,


because they're obviously they're not


going to give you real live capital if


they don't even know if you know what


you're doing.


So what I what I found on trading view


if you if you trade on the dom paper


trading


you can literally watch the trade the


the price


and if you buy on the if you basically


buy on the bid


right when you enter on on the mini


micro I mean you can be positive $600 in


two seconds


Right.


>> And what what that's telling you is that


they're giving you the best fills. You


know, until you go to reality,


um your fills are not going to be the


same


or or they can if you actually get it


right with the explosive, but you know


to basically you'd want to get filled


buy on the bid and sell on the ass.


Those are going to be your your best


prices to get filled at it in the


market.


>> Yeah. and not get


>> sorry and I don't mean to cut you off,


but before Tatum hops off, I was I want


um


>> Yes, ma'am.


>> I just want to give give Tatum a chance


to answer or ask her question real


quick. Go ahead, Tatum, if you want to


come off mute.


>> So, I placed a trade


on US30 this morning


after open.


It was


You see that big fat W?


>> Uh, let me let me pull it up real quick.


>> Are you talking about on the one minute


time frame like around 9


>> 9ish?


>> Yeah, 9:30.


I was watching it go up there. It pulled


back and then broke


those two.


>> Yeah.


>> Previous. So I got in at market for a


buy and I had my stop loss.


Okay. Okay.


Um


below


it. Well, it knocked me out of course.


So,


>> did I not see something?


>> Um, and I don't I don't think I have um


actually hold on, let me just pull it up


right here.


>> I was looking at it over on this chart,


but um let me look it up over here to


see. And my lines might of course be


>> which it wasn't around any of my


hesitation areas


and those could have been off which is


probably could be why.


>> Um okay. So like right right in here. So


did you have your stop loss like at


least below


below these?


>> Let's see where you're you're at 920.


Yes,


that's the W there, right?


>> Uh, yes, I think so.


>> I think you've got S&P up, Shay. And she


was at 30.


>> Oh, hold on.


>> They're basically the same except SMP


was a lot better.


>> Okay.


>> Is this it?


What am I on?


Just go to YM. I mean, I don't think


they're any different. That's it,


though. Yeah. You see this big fat one?


You see? Mark it open.


>> Okay. So, let's see. Nine.


Shrink that down. Okay. So,


>> there. Or


>> So, you got in when it broke that


structure


>> right there after it broke the next V


over. Yeah.


>> Okay.


So,


>> so I probably if I would have gotten in


here just kind of going off of this


resistance area, I probably at least


would have had my stop loss below this


previous low right.


>> So, did you get knocked out over here?


>> Yeah.


>> Okay. Um,


what time was that?


And see, I don't have my 15 hour or 15


minute there. I think I have it higher


up.


>> Um, well, I was going to say and I


haven't mo moved mine since like


yesterday before market open.


>> Um, I haven't adjusted it. So, I was


going to say depend on when you marked


yours up.


>> Um,


>> this morning. Yeah, you may have already


kind of like adjusted for it. Did you


have yours like more like in here


or wait? Let me see.


I'll tell you


>> what was that 12. Yeah. See, like


>> 457.


>> Uh what was it? 45 what?


>> 457


and some change. Whatever.


Oh, that's where you have your 15 minute


down here.


>> Uhhuh. Yeah.


>> Okay.


>> I'm sorry. I'm trying to feed the


>> Oh, no. No. You're fine.


>> I don't think any of us will ever


complain about baby noises.


>> No, I can practically smell that baby.


I'll be smelling bad here in a minute.


>> Let's see. It says yesterday


14th


12.


>> Okay, I'm getting more.


>> I was going to kind of quickly um


adjust these real quick.


Do it.


>> Do that.


I don't know. If I was to adjust this


right now, I'd probably maybe go like


here.


>> Okay.


>> So, let me go back and look at


um


>> it bounced off the one hour.


>> Yeah. So, um yeah, maybe that's what it


was


>> probably. Um, yeah, cuz it looks like it


it went, you know, tested it but then


broke below that. So, um, yeah, I bet


that's just what happened.


But I mean, that that is a really pretty


W.


>> Yeah.


>> So much for it.


>> I watched it all morning. I was like,


okay, here it is.


Um


yeah. Yeah. I think it was just a


um just a


weird And honestly it may have even


>> it's going to keep going down.


>> Yeah. Maybe even like in this area.


>> I know. I guess it did hit that over


there. But yeah, I bet I bet that's all


it that's all it did. And then of course


now we'll see if it continues to go down


or not. But um but yeah, I mean outside


of it just kind of hitting that 1 hour,


you know, hesitation area.


>> Um other than that


um yeah, I can definitely see


>> see what you saw. You know, W EMAs cross


break a structure.


>> Okay.


>> It just sucks that the break structure


was like


>> Yeah.


That's right.


>> All right.


>> You're you're on the right track.


>> It is what it is.


>> Oh, you okay?


>> Oh,


during during this call, gold hit an


alltime high again.


>> It did. It really?


>> Yeah, it did.


>> I'll have


Yeah. I haven't even and I think I um I


am also still in the um


the trade that


that I took on the micronas.


>> Yeah, I see that at the top of your


screen.


>> Oh, okay. Okay. That's where I have I


have y'all up there, so I couldn't even


uh I couldn't see that. Oh, yep. I am.


Yeah, good job.


>> Yeah. So, we'll see.


And actually, I think this one might


have got I don't know when this got


triggered in. Maybe while I was on the


call because there's not even a


stop-loss. So, I'm going to go ahead and


add that at least. Um and then we'll uh


we'll just


let it ride. We'll see what it does. But


um all right, guys. Well, if um


>> I have one more question.


>> Oh, yeah. Go ahead.


>> You're not doing the um 8:00 uh live


calls anymore


>> on Monday night.


>> Tonight


>> in the evening. I am in the evening.


>> Well, they moved to 7.


>> Oh, I missed that part. Okay.


>> Yeah. So, we uh we changed all of that


and it's um the calendar in circle it


reflects that change. Uh, so if you um


whenever you get ready to, you know,


like log in tonight,


um it'll it'll have the 700 p.m. Central


time.


>> Oh, I like that time change.


>> Yeah,


>> open,


>> I think. Um, for one, it's like almost


my bedtime, like 8:00 at night. Um, but


I've also noticed that like sometimes


the market's already kind of slowed


down. So, if we hit it maybe more at,


you know, like the Asian open,


maybe things will kind of be moving a


little bit more, you know, for that


hour. But um but yeah, either way, we'll


uh we'll kind of test it out and see um


see kind of what we think of of that


time change. And like I said, the


evening thing now that I don't trade


crypto is um


you know, is kind of new to me. like I


don't trade enough at that time to


really know what moves really well other


than crypto and sometimes gold. So, um


we'll kind of play around with it a


little bit and see see what we think.


But, but at least the ones that are on a


completely different


time zone across the world, they can um


you know, get a little bit of that live


live scalping call with us.


Um, all right guys. Well, if y'all think


of any other questions that you might


have, um, if you are questioning on


uploading a chart or stop yourself from


posting, don't. If it makes you feel


better, just throw me a message. and um


you know if you are questioning it but I


just want to make sure that we


that we keep on a good path and don't


get ourselves confused too much. So um


all right guys, well y'all have a good


day and if y'all hop on tonight's call


with me then I'll see y'all at 700 p.m.


Central time. Okay, I'll talk to y'all


later. Five.$video_13_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_13_summary$This lesson separates individual confirmations from the full strategy. Shea explains how different confluences work together and why a few good signals still need to fit the overall trade idea.$video_13_summary$
      ELSE summary
    END
WHERE sort_order = 13
  AND title = $title_13$Confluence vs Strategy$title_13$;

-- Backfill watch-page content for lesson 14: Managing Risk & Securing Profits
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_14_transcript$All right. So, today I'm just going to


kind of go over um basically like risk


um what you should be risking on your


account or what I would suggest you risk


uh what I would suggest you not risk.


Um, and just kind of managing your trade


once you're in it and just to help maybe


eliminate some of the stress that can


come with it and maybe some of the


reasons why if you are feeling a lot of


stress and anxiety. Uh, some things that


could be causing it. uh or in my


experience anyways just um things that


have caused me to maybe stress out


more if I'm in a trade. Um, of course


the you know


you want to view it as that you know


your risk is


use it as a a tool not you know I guess


a threat basically. Okay. So, if you're


setting a stop loss, don't get so caught


up with uh


like the amount of your stop loss and


kind of just stress yourself out of, oh


my gosh, if this hits my stop loss, I'm


going to lose, you know, $500 or


whatever your risk is. Um, you know,


just view it as you're protecting your


capital. So, um, you know, maybe the


first thing is to view your risk as a


tool, not a threat. Um,


and just kind of some things that can


help you out,


maybe eliminate some of that stress. So,


the first thing of course we want to


remember is um,


let me make a box.


is we want to remember our you know


confluences. So whatever those are that


you kind of stick with um you know you


want to make sure maybe to just not even


get in the trade until all of your


confluences are checked off. uh you know


so that will help you of course uh just


know that you know I saw everything


everything was lining up for you know to


get in the buy and if it for some reason


reverses on you which of course it does


happen but it'll at least help eliminate


some of that stress of knowing you at


least checked off your boxes and and


then it kind of same thing goes goes


along the lines of, you know, your


rules. So, you know, I'm not going to


immediately get into a sell just because


say I see price reacting off of this


4hour uh resistance. So, you know, just


kind of have your set of rules laid out.


And,


you know, if you can check your


confluences off and your rules, then


a lot of times it'll help you at least


go into the trade, not like stressed


like from the gate. You know, you want


to just start your trade relaxed. Um,


and you know, and just I know a lot of


you guys already know this, but you


know, just don't forget that you're


whenever you get into a trade that you


know, you're basically


um


you know, you're managing a probability


um not not certainty. So, I mean, if you


get into a trade even based on your, you


know, confluences being there and you


followed all of your rules,


um,


you know, sometimes it just goes the


opposite way. But, um,


I know a lot of you are already in prop


firms


and I know each one of those are kind of


different, but you want to kind of start


out


knowing exactly what you want to risk.


So, you know, I would definitely say


risk no more than


either 0.5%


to


1% and I would say 1% at


the very most. um you know cuz even on a


say a $50,000 account I think that's


what a lot um are on the top step you


know that's you know $500 so um I don't


know what the draw down is


on a $50,000 account but you know you


don't want to risk it all on one trade.


Um,


if you do that,


you are definitely going to go into that


trade


stressed out because all you're going to


think about is if I hit my stop-loss,


you know, I'm going to breach my


account. So, um, so you want to risk no


more than, you know, 0.5 to 1%. Um,


don't revenge trade,


which I think that's kind of a given.


Um, you know, if one hit your stop loss,


just go on and, you know, don't


immediately try to


jump back into the trade and, you know,


risk more to try to make that back.


And you want to


set take profits


and stop losses


at key levels. So of course


say here for instance


or kind of like we did this morning


you know take profit I always go inside


my next key level if I'm, you know, kind


of aiming for that next area.


So, inside


for take profit and then for my stop


loss, I go outside and I try to


go below


the previous low


before it crossed. That makes sense. I


feel like it was easier to kind of show


you guys.


So, price crossed over


and came back before we went up. But I


want my stop loss


below this area


just because I feel like a lot of times,


you know, if a stop loss is going to get


taken out by a liquidity grab, a lot of


times they know that, you know, we have


our stop losses around these key areas.


So that's when, you know, you'll kind of


see like a strong wick reaction to kind


of get you out. So I always just want,


you know, my stop loss to have a little


bit um a little bit more room.


And then um


I kind of made a checklist


for you guys and you can kind of um add


to it if you want. Uh but just some


things to kind of have


kind of in the back of your mind once


you're in a trade. Um you want to kind


of already know, okay, if it gets to


maybe the next key level, then maybe


that's whenever you want to wait to move


price to maybe break even or into


profit. Um y'all know a lot of times I


don't do that. Uh so say if we get in


like right here this morning, you know,


my next key level was this 4hour


resistance. So I'm personally not going


to let my trade get all the way up here


before I move it to, you know, a minimum


break even. Um, so I know a lot of times


the distance isn't this big, but


but if you, you know, want to kind of


just play that by ear, say if you were


down here getting in a trade and you got


triggered in, you know, that distance


isn't as big. So, you know, if you want


to wait until price gets here and maybe


set your alerts before it, that way you


get notified, you know, if you don't


want to maybe sit there and stare at the


trade and know that, you know, once this


alert gets triggered, then, you know,


then I'll move my stop loss to break


even or in profit and, you know, but


just kind of have that in the back of


your mind. So once you're in the trade,


you're not


making decisions off of like your


emotions because either it's in, you


know, a little bit of a pullback or


it's, you know, you're in profit and


you're just trying to hurry up and make


a decision, you know, quickly on I want


to just close out. I want to take this


profit or it's in, you know, a little


pullback and I just want to close out


because it's in a little bit of a


pullback. So, kind of go ahead and have


your plan lined out. Um, even if it


changes with each trade or depending on


which instrument you're trading, of


course, how I would treat maybe NASDAQ


versus gold versus USD JPY, you know, I


would treat them all a little


differently


just because I know the


the volatility is different with each of


them. And


I guess maybe my comfortable


comfortability


that didn't want to come out. Um it's


different also. So how I feel about NAS


and how much longer I'm willing to maybe


um


just kind of be okay and ignore a little


pullback versus if it was one in gold.


You know, I don't trust gold as much.


So, you know, that's where my emotions


would maybe kick in is if I was say


trading gold. Um, so just kind of have


that already planned out a little bit.


And you know, that will also help. um


you know if you want to have a certain


area of if I get a maybe a one to one or


a one to two then that's whenever I will


do a partial close. So um


you know whatever that kind of looks


like for you. Um, I know I also get the


question a lot of if I say if I'm in a


buy and I start seeing signs of


reversal. Um, if I would just close out


my trade and I I never do. Um, so in


case you maybe haven't been on a call


where I've talked about that. Um,


even if


I guess I'm in negative, it doesn't


matter. um it will either have to go and


hit my stop loss um or if I'm in profit


already


and I'm say trailing my stop loss


already um you know behind these one


minute let me get on the one minute time


frame.


So


I'm going to go back to this one. So,


say I get in, I enter into the trade and


I'm in profit


and


say I'm trailing my stop loss up


and


say I didn't move it up until this one


minute fractal.


So, I'm in profit. My stop loss is moved


up into profit and I'm man manually


trailing it. And so say we get up here


and I see this fractal right here give


me a change of character.


Of course I see this


right here


and this fractal


but my EMA of course has not crossed


yet.


So,


I know there's um probably a lot of


people that would see this right here.


For one, you either have like a little


bit of hesitation and then you see that


fractal go below that fractal. So, we


didn't get a higher high. We didn't get


a higher low, but we got a lower low.


You know, y'all would just immediately


close out. And that's fine. Um, if


you're, you know, if you're in profit


and you're good with those profits,


then, you know, it's, it's okay if


that's what you want to do and just


close out completely out of the trade.


Um,


you know, I personally wouldn't, but of


course, I would be trailing my stop loss


up. So if I do feel like I'm starting to


see multiple signs that we're getting


ready to reverse. So of course for me if


I started seeing this EMA cross when I


have already seen this lower low the M


um you know all of those signs and I'm


kind of getting like the three to four


confirmations that that maybe we're


getting ready to um reverse.


I may just pull my stop loss a little


bit closer and either just get knocked


out, you know, by trailing it. Um,


you know, or just leave it and just kind


of keep going up with my fractals until


it just naturally kicks me out. Um, so


that's kind of just always been my


um I guess kind of my set


rules that I've always followed whenever


I'm in a trade and kind of uh managing a


trade once I'm in it is, you know, I


won't ever close it out in the negative.


Um,


it doesn't matter if I see all of my


signs that it's reversing. Um, I'll just


let it immediately close. And then if


it's still kind of looking like I think


it's just going to go the opposite


direction, then I'll just get into, you


know, say a sell. If I'm going to buy,


then I would just get into a sell. But,


um, but I won't ever close it out in the


negative. And I think maybe one of the


biggest reasons why I don't, especially


with NAS, is a lot of times it can get


like really close to my stop loss and


then just


go back in, you know, the direction that


I was going. So, you know, I mean, it


could come all the way down here and


then just reverse and go back up into a,


you know, buy direction. And I think


maybe I've seen that happen enough that


um that I just let it kind of play out.


I set my stop loss where I feel like


it's a, you know, a secure enough


position or at a secure enough price um


to where if it gets stopped out and my


stop loss gets hit, then it probably


would have anyways. So, I just don't


worry about it. Um, another thing that I


don't do is if I have my stop loss here


and maybe I start seeing signs of


reversal or you know the price is kind


of getting near my stop loss is I don't


move it.


And I def highly highly would suggest


y'all not to also um you know cuz I feel


like I feel like I give my stop loss


extra breathing room anyways. So


I feel like if I were to move my stop


loss down further just out of really the


fear that it's going to get hit. then


it's coming down into an area that,


you know, more than likely if price were


to come down,


we're going the opposite direction


anyway. So, all it's going to do is just


make it to where I end up, you know,


losing more money. So, um, so I wouldn't


ever


move your stop loss. Once you have it


set, just just stick with your plan and


keep going. You know, just either set


alerts and close your charts to where


you're not looking at it maybe in draw


down and,


you know, that should help you maybe a


little bit just not be um


be as as stressed out, you know. And um


I don't remember what book it was in but


but I've always liked the saying that


you know protecting your account with


your risk management is is considered


trading you know cuz that's the main


thing is you want to protect your


capital. That's kind of the big game


with trading. And of course, profits are


a side effect of proper risk management.


So, you know, don't ever feel like if


you don't profit on every single trade


that that you're not doing something


right or that you're, you know,


not following your rules or that you're


not understanding, you know, the


strategy.


um you know cuz it it doesn't mean that.


So um just know that if you set your


your confluences, your set of rules,


whatever you want to go off of, whether


it's the fair value gap, support and


resistance, you know, break a structure,


any of that. Um just have it listed. and


I don't remember who it was, but


somebody had said that they listed


it on their charts. And


I think that's a great idea. So, you


know, whether you just copy and paste it


to whatever chart you want to get on, um


maybe just seeing it visually on your


chart, you know, whichever ones


you go off of, maybe list them, you


know, most important to, you know, to


ones that maybe aren't as important to


you. and you know maybe maybe have the


rule that you are not going to get in


unless you see maybe minimum three to


four uh confluences. I would say for me,


these are probably my list of importance


down to what I really don't pay


attention to. And I would say whenever I


get into a trade, I probably see um


I probably almost go with these first


four to five uh before I really feel


comfortable getting into a scalp. Um you


know, of course, uh support and


resistance reaction is my number one.


Um,


and I will get into them, especially


this where I have like a really big


distance.


Um, let me delete that.


Um, and say if I'm just getting on the


charts and through the night or whenever


I wasn't looking, it had kind of done


all of this, you know, the initial


reaction off of that uh 1 hour


resistance.


then, you know, I won't necessarily wait


until it gets all the way back up here


or pulls back and comes all the way, you


know, down here. So, um I don't


necessarily


have to wait on that. Like I will get in


halfway. Um, and


I'm just a little more careful and I


know that maybe my stop loss won't be as


protected as say it would have been


below this 1 hour support. So, you know,


it just kind of depends on how um you


know, risk adverse you are. if if that


maybe would cause you to have way too


much stress and the first sign, you


know, say if you get in right here and


say this first little sign of just a


little baby pullback,


if something that little would just


cause um cause you to have a lot of


stress or exit out immediately,


um then then don't do that. Just wait


until you know your rule is kind of like


set, you know. Um and don't veer off any


from that. Um but like I said, I I will


get in even if this is a little I guess


in a gray area. Uh but but I just know


going in that that that my stop loss


just won't be in as a as good of a


position as it would have been if I


would have waited. So, you know, just


just have your set of rules and if you


kind of veer off from them a little bit,


be okay with whatever might happen from


you, you know, not sticking to that um


that confirmation that you have set. and


and so I so anyways I want a reaction


off of


a key level and then of course I want my


9 and 21 to cross.


I want to see a W.


So, I'm going to kind of pull this up.


And


so, you can see we had a reaction off of


this 1 hour resistance line.


I had my EMA cross. And of course,


that's another thing. I'm okay with it


crossing on the one minute as long as I


see other, you know, confluences that


are going along with it. So,


of course, I see my


my W. Whoops.


So I see my W,


my EMA cross,


my higher low, higher high. So those are


kind of the big ones on my list. So um


and then of course we had a break of


structure.


So once I saw it break this high,


then I would have been good to get in.


So just have whatever yours are, just


have them on your screen so you can, you


know, always just kind of see them and,


you know, before I get into a trade, I


want at least, you know, three, four,


whatever it might be. Um, you know, of


course, if it's a fair value gap, then,


you know, maybe you don't get into it


whenever it has like it's an initial


reaction. Um, you know, so if price came


down,


let me see if I can pull one up real


quick.


Okay. So maybe say if you were looking


at


this


fair value gap,


you know, that's kind of maybe like high


on your rules of I'm not getting in


unless there is a reaction.


into a fair value gap. So, you know,


maybe you


just kind of, you know, you don't want


to immediately jump in as soon as it's


tapped into. You know, maybe you want to


see u


you know, a second reaction for


instance. Um, which a lot of times


if you let price


come down


and then come up and then let it have


another reaction, which I know my W's


not on the right candles, but um, you


know, maybe maybe that will make you


feel a little bit more secure about your


scalp is if you don't just immediately


jump in just as soon as the fair value


gap is tapped into. You know, you maybe


don't want to immediately get in. Maybe


you want to see a second reaction, which


of course, you know, could give you a W,


you know, if if that is even on your


list. But um but I always feel like


maybe if it can have another reaction


then


you know maybe that just makes it a


little more safer. And it might also be


cuz I I don't really just enter on fair


value gaps. But um you know of course


like this one for instance


or even this one right here.


So this one right here


with it being near this 1 hour


resistance


I would hold a little more weight into


that fair value gap uh because we have a


you know it's a bullish fair value gap


for one so you know whenever it came in


these orders


filled it


it is near this key level. So that's


almost would be confirmation for me of


okay we got a you know tap down into the


fair value gap prices were or you know


the orders were filled


we didn't keep going below this 1 hour


support


and then you know of course if you are


looking at the W's uh and the EMA cross


kind of the same area um But, you know,


so maybe


maybe look into it as um you know, fair


value gap. You don't want to just


blindly jump into it if it gets tapped


into


unless maybe it's near a key level or


something like that. So, um just


whatever will maybe make you


not immediately get into the trade


stressed out. That's kind of the


the biggest thing that you want to try


to remember is to stay calm. Um, of


course, before you set a trade because I


feel like it just allows you to see it


like more clear. Um, you're not trying


to force a trade. um you know, maybe if


you only see one or two confluences,


you don't try to talk yourself into


like just getting in just based on that.


Um


you know, because you just want to try


to force a trade. So, you know, don't


force a trade. Um make sure all of your


confluences are there. Um,


of course, getting good at losing a


trade is always good. That will help um


get some of those stresses out of your


system if you can, you know, see that


maybe you followed your rules and the


trades just didn't work out. But the


fact that you followed your rules trumps


the fact that you may have lost the


trade. So, you know, just get to where


you are comfortable losing your trades


and,


you know, it'll kind of help it to where


with you following all your rules that


I don't know, you just won't stress out


as much. And I think that'll keep it


from where you know you getting into a


trade and it starts going down into draw


down a little bit and you either


immediately panic and want to close and


draw down or


you know


or just stay stressed out.


That's never good in a trade. So, um,


I'm going to look and


just make sure that there weren't any


questions in here that


maybe I need to address before I get


get too far away from something.


I also got pulled this uh calculator. I


saw a comment about how to calculate


that. I know especially with um with


futures since, you know, it's not as


easy as like it used to be where you


could, you know, get your order box and


put your take profit and your stop loss


where you wanted it and then get into


the trade. Um


but there is this


and I know this was shared in the um in


the circle classroom. Um somebody this


morning was asking about doing like a a


section like a separate one for


resources and I think we're going to go


ahead and do that. So, I'll be sure to


put um this calculator


in that section so you can find it a


little bit easier.


And so if you pull up your chart and you


know say if you're looking at NAS and


you know say if it comes up and we have


a reaction off of this 4hour support and


from there maybe you are debating on


getting into a cell. So if you want to,


you know, maybe say go ahead and draw


your box


so you kind of have it visually laid


out. Then, you know, you can come over


here


and then


in this calculator, if y'all haven't


used it yet,


right here, you which pair you're


getting


and where you would want your entry


price. So, of course, for this one, it


would be this


232


And then same thing, put your take


profit. We're


try and do this quickly. And then stop


loss. So, say if you wanted your stop


loss or wanted to kind of see if this is


where you would want to place it.


Is that right?


>> Yeah. Let's do 318.


And then say you were maybe debating on


just getting in one contract.


So then you just hit calculate.


And


I've got that backwards, don't I? I was


like, that don't look right.


Let's reverse these. See, you can tell


I'm not used to getting in sales.


Where was that take profit?


Oh, I know why. No. So, I did have that


correct, but you have to click short.


That's where I was going wrong.


Okay. So, we did have this this correct


the first time.


Now, let's calculate and see what it


does.


Okay. So, it'll it'll tell you your


potential loss, you know, depending on


if you want to I know some people just


go off of ticks, like I want a 10 tick


or a 10 pip uh take profit or whatever.


So, it'll kind of tell you either way.


Um or, you know, dollar amount and then


what your potential take profit would


be. So, if that's something that you


maybe want to set up ahead of time so


you kind of just um you know


aren't risking too much. It may also let


you know if you want to get into the


regular size or a micro or a mini. um


you know so just look at that calculator


and maybe whatever pair you are you know


maybe trying to really learn


you'll eventually get to where you just


know that you know a stop loss roughly


you know this size is a certain dollar


amount and you know so it'll either have


it to where you can wait until


you know your stop loss is a lot safer.


Uh if you want a little bit more


cushion. So just uh try to use this


calculator especially if you're new to


futures and it'll kind of help you know


all of that


before you just get into it. And you


know, I know like for me, um, whenever I


was learning futures, like I would just


execute it and then drag my stop loss


and hope for the best cuz I um I just


couldn't figure out how to calculate


all of that. So, um,


so yeah, maybe just


download that calculator


and like I said, we'll put it in the a


resource tab in circle.


I'm going to look through the chat real


quick.


Uh me personally, I am okay looking at


my confluences on the one minute time


frame. Um,


if it's


maybe depending on like what has


happened either with the pair that I'm


trading or maybe reaction to news, if


I'm ever,


you know, maybe questioning one of my


confluences or an area or anything like


that, then there are times that I'll


wait until I see maybe an EMA cross or


something like that on like the five


minute. I usually don't ever go as high


as the 15 minute, but


like for instance, if I was to trade


gold um and it wasn't like a an obvious


direction, then I would maybe think


about waiting for my EMAs to cross on


the 5 minute or the 15 minute time


frame. But other than that, um, like


with NAS, because that's mostly what I


trade, I'm okay with just seeing them on


the one minute as long as, you know, I


see these other confluences to go along


with it.


Yeah.


Sorry, I'm just reading the chat. If


there's um


if there's something that y'all were


wanting to ask and I haven't got to it,


you can definitely come off mute if you


want to.


Um, so yeah, if I would just make sure


you have your confluences list out, your


list of rules,


you know, maybe on your chart as well.


Um, if you go into a trade and you are


immediately


stressed out, um, it could maybe mean


that you're, um, you know, you're


risking too much. uh you're in a you


know maybe one of these that that you


either shouldn't be based on your size


of account um or you're just not


comfortable with. So, you know, if maybe


you're only used to trading with micros,


which which I think is definitely um


smart, um you know, especially if you're


if you're either new or,


you know, just maybe kind of trying to


figure out what confluences you even


want to stick with. um stick with the um


with the micros, but you know, so if


you're only used to that and then maybe


the next day you just want to jump up to


regular NAS, like there's going to be a


big difference and it's probably going


to, you know, cause you to stress out a


little bit. So, um, so yeah, usually if


you're going into a trade and you're


immediately,


uh, stressed, you're either, um, you


know, trading


or risking too much, either too big of a


percentage,


um,


you know, you're maybe not placing it


where you would feel more comfortable.


So maybe outside of a key level. Um if


you were to maybe get in somewhere here


in the middle, it may kind of stress you


out a little bit to know that your stop


loss would be way too big down here and


it's not as safe in here. So um you


know, just maybe kind of try to figure


out why you're immediately getting


stressed out. Uh, but more times than


not, it's you're either risking too


much, you're trading a pair that, you


know, just cost more money for each


contract. Um or that maybe you're um


you know not being as patient, which of


course comes down to maybe your


confluences weren't all there and you


just felt like you needed to maybe force


that trade. whether it would be revenge


trading or you know a FOMO thing because


you see people in the chat talking about


getting into something and being in


profit. um you know so kind of try to


decide whether it's through back testing


or you know journaling your trades and


actually journal down you know if you


got into the trade and you immediately


were stressed out then you know maybe


look back on that trade and see if maybe


you were just risking too much and


that's what it was all stemming from or


maybe you didn't have enough of your


confluences or got in at, you know, the


wrong place or something. Um, you know,


a lot of times,


you know, you may get in maybe a buy,


you know, but you see everything playing


out right here, but you don't look at


the big picture and you don't realize


that you got into a buy maybe right


below this 4hour resistance. And you


know then once you realize that it could


you know cause a little bit of anxiety


because you know that sometimes it can


have that reaction and reverse. So you


know just try to have patience make sure


all your confluences are there that your


rules are checked off. Um don't risk


more than what you should be risking.


Um, you know, of course, don't revenge


trade and,


you know, just kind of have all of that


laid out before you even get on the


charts. That way, you maybe are more,


you know, more likely to just kind of


stick with everything and you'll be


surprised how much that eliminates a lot


of that stress for you. Um, and if you


guys want to, and it's not anything you


need to upload it into Circle. Uh, you


can if you want to, but just to


kind of get you guys more used to doing


all of that. Um, you know, just track


maybe your next three trades and, you


know, put your entry, where your stop


loss was, the stop-loss size.


um you know how much you were risking


and


you know then after the trade completely


plays out then go back and just you know


see if you followed whatever your plan


is, whatever your confluences are. um


you know, whatever your rules are and


just see if there was any any of them


that you kind of veered away from and


and see if maybe it was one that you did


feel stress or you, you know, kind of uh


had that urge to close it, you know,


close it earlier than you normally would


have. Um, you know, of course, do this


all in a demo. That way you can maybe


let it play out fully uh without risking


your own capital, but you know, already


have kind of in play where when you're


going to move your stop loss to break


even, when you're going to move it into


profit, and have all of that already


lined out. And then just for the next


three trades, just let them fully play


out. Um whether that's I'm not moving


it, you know, I'm going to let it just


go to that next key level. Uh see how


that plays out. Um you know, if you move


it to break even when you're at a one


one, then you know, just kind of see how


each one of those plays out and and if


maybe you had stress during any of those


three trades. And if you did, um, just


kind of look back and see if maybe you


can pinpoint what caused you to maybe


feel that stress. Um, and like I said, a


lot of times it's


usually because you either weren't


patient or got in the wrong place when


maybe you shouldn't have, um, or was


just risking too much. or of course


revenge trading uh where you just almost


immediately go back in and once you're


in it then you know you look back and


it's like crap I got in a really bad


spot. Um and I know I've done that


hundreds of times


which is of course how I maybe know what


not to do now. Um is because I've done


all that. So, um, but yeah, definitely


just journal your trades and see maybe


what is causing you to have the stress.


Um, you know, another big thing is just


the strategy in general. Um, I know that


kind of can get wrapped into the like


confluences, but you know, if you're


maybe trying to


do too many in a way. So if you're


trying to mix up uh say 10 different you


know strategies whether it's you know


support and resistance and then trend


line and


it's almost


overwhelming for you to feel like


instead of maybe just three or four


confluences


you're almost waiting on like that


perfect pair and you realize that you've


now given yourself a list of 10 and I'm


not going to get into the trade unless


every 10, you know, all these 10


strategies all line up together


because more than likely they won't. Um,


and if they ever do, then you're not


going to be trading that much. So, um,


you know, just


just try to make it as simple on


yourself as you can. And a lot of times


that's confluences, rules, patience,


proper risk management, and of course


knowing how you're going to manage the


trade once you are in it. So, um,


yeah, if y'all have any questions, let


me know in the chat and I'll try to


answer a couple of them before we get


off.


If not,


do this little homework assignment. Like


I said, you can either post it in circle


if you want in that little homework


section um or just have it for your own


benefit just, you know, for you to go


back and and look at because it'll help


a lot.


>> Hi Shay, it's Heather.


>> Hey.


>> Um hi. I'm wondering about


probabilities. I get very confused about


like I think it's


probable that I'm gonna pick all the


all the trades that lose. I mean, do you


have to go into a certain number of


trades with your confluences before the


probabilities kick in? Like I just don't


understand how it works very well.


>> Um, you mean as far as like to get like


a a certain win rate or something?


>> Exactly. Yes.


>> Um I mean I don't I don't guess I ever


really did. Um


but like if you're wanting maybe to see


kind of what your average win rate I


guess um you know for instance is then


you know I think that's where maybe


either the journaling of your trades


you know maybe like


I don't know maybe if you're doing


something like that maybe do like 10


like 10 trades where you know you don't


enter them unless


like all of your confluences are there


then you know maybe take the average of


like the 10 trades and just kind of see


you know see how they your win rate


averages out at the end of it. Um but


but yeah, and I would also make sure


that um that you would journal in there


if for some reason news hit, you know,


while you were in the trade because that


can, you know, kind of fluctuate


the price enough to where either you're


getting stopped out when maybe you


normally wouldn't have or the opposite.


you know, you could it could hit your


takerit in 10 seconds where where maybe


normally it wouldn't have. So, um, so


yeah, I would maybe try just either


journaling your next 10 trades or going


back if you have, um,


if you have trade locker


um, and know how to have you ever used


the replay button or do you have trade


or not trade locker uh, trading view?


>> Yes, I do. Yeah. And also, I mean, I


have top step, so it's it keeps a record


of all your trades and does some really


interesting statistics on them, right?


>> Yes. And it Yeah, cuz that's why I like


it. It's like got that Tradezel almost


built-in journal.


>> Built in. Yeah.


>> Yeah. So, um Yeah, you could definitely


look at that. Um, but I would still have


written down next to each one. Uh, like


you entered based on these confluences,


you know, that way um because I know the


like kind of the builtin top step thing,


you know, it has like some of those um


I don't even know what all it has in


there, but it kind of breaks down, you


know, each one of them. Um, but but just


have it written down somewhere


like what confluences


you entered like based off of and and


then same thing maybe exited from as


well whether it was it just hit your


takerit at the next key level or you


know maybe you were trailing it


you know based on a fractal you know


like I do it based on the one minute


fractal.


So maybe if you trail it, if you do it


the same with each one, you know, maybe


write down what that is or or maybe you


do them, you know, different depending


on which pair you're trading. So just


make sure to write all of that stuff


down. That way, even if it's not just


you won, you know, seven out of 10


trades, but you know that you had that


win rate because you waited on


four to five of your confluences, you


know, or something like that. That way,


you'll just kind of know um


what what made it to where you won that


trade or of course lost the trade. Um,


and that'll kind of help you


know, you know, maybe moving forward.


Um,


because of the win or loss rate, you


know, you may want to change,


you know, something up or leave it the


same. Of course, if you have a really


good win rate, then I would say stick to


doing whatever you were whatever you


were doing, you know, to get that. So,


um, but yeah, I would just try that. I


would try maybe the next 10 trades, um,


you know, or back test if you want to


using that replay mode. So, um, with the


replay mode, I would, you know, maybe


just get on,


you know, this


1 hour time frame


and,


you know, or whichever whichever time


frame and I would just kind of blindly,


you know, and if you need to close your


eyes so you're not like, okay, I know


after this it went in an uptrend,


you know, then you can do something like


that. But um but yeah, I would just um


do that and then just go through the


list and see if um you know if you would


have entered and do your long short tool


and


then just hit play and see kind of how


it how it played out. And I think that's


a really good idea to do.


>> Thank you very much. That's helpful.


Thank you.


>> You're welcome.


uh FA the uh the journal that they're


talking about in


uh in top step


if you uh pull up your


I don't know if I've


I don't know if I've found it on my


phone, but I know if you're on the


computer on the left hand side of the


screen


um let me get this pulled up


and I'll


I will show you real quick.


So on the computer


if you


hold on right here performance stats


right here this is very similar to trade


zilla so you know it'll tell you your


most active day most profitable


average trade duration


I I think it tells you quite a bit of,


you know, really good information.


And then


down here, it will tell you, you know,


week, week by week, what your


end profit or loss is.


And then I was thinking there was


somewhere


that you could upload it


like if you wanted to save it. Oh, maybe


just right there. save layout.


And then, you know, if you wanted to


maybe print it or something.


Oh, okay. I don't think I knew that. Um,


let me pull that back up.


So,


oh, interesting. Okay. Well, that's good


to know. Yeah. So, if you click on the


day,


yeah, you can just add your


your journal entry.


Didn't know that was there.


Okay. You can only journal on the days


that you've actually traded.


Okay. Well, that's good to know.


All right, guys. as well. If y'all don't


have any more questions, then um


then I'll go ahead and let y'all on to


your your little homework assignments if


you want to do them. And um yeah, just


let me know what y'all come up with. And


like I said, you can either put it in in


circle in the homework section or um


or just keep it for yourself cuz I do


think it's really good information to


have. So um yeah, let me know if you


guys have any more questions. And like


always, if you put a question in circle,


just make sure to tag me. That way I


make sure to get the notification.


All right, guys. Well, y'all have a good


day and I will see y'all tonight if you


get on the live scalping call with me.$video_14_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_14_summary$Shea covers position sizing, how much to risk, and how to protect yourself once a trade starts working. The goal is to help you stay consistent and avoid letting one trade do damage to your account.$video_14_summary$
      ELSE summary
    END
WHERE sort_order = 14
  AND title = $title_14$Managing Risk & Securing Profits$title_14$;

-- Backfill watch-page content for lesson 15: Taking Profit Options
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_15_transcript$Okay. So, first I am going to um


get my chart pulled up.


I'm going to go through and just kind of


show y'all some different options with


um


you know taking profit early things like


that in case you you know I know a lot


of us have been like moving our stop


losses up pretty quick and then like


we're either getting stopped out and


then we watch it go up to our takerit.


Um, I know that's happened quite a bit,


but you know, y'all are probably like I


am and


you know, I've just been very cautious


with the charts here lately.


Kind of get this up where my notes are.


Um,


but I'm going to try to like not do that


as much just because I feel like


hopefully the charts are kind of calming


down. Um, and


so just to kind of give you guys some


other options if you don't always want


to like move your stop loss up, you


know, fairly quickly. um just some


different things that I have done in the


past and I still periodically will do


them. But um you know you can just kind


of play around with it even go back and


you know maybe um back test a little bit


and see which one maybe would have kept


you in the trade a little bit longer.


But then again, I know with the way the


charts are, even back testing may not be


very accurate with the charts, you know,


being a little more calmer going forward


hopefully. Um but um one of the I would


say


the next most popular thing that I have


done outside of uh just immediately


moving my stop loss to like break even


is uh scaling out. So taking partial


profits and um and it depends on what I


kind of initially set my takeprofit. So


if I'm going to, you know, maybe like


the next support or resistance area and


it's maybe like equals up to say a one


to two risk-to-reward,


then I might look at taking partial


profits at say a one one. Um, so you can


kind of just determine where you maybe


want to do that. So either at a one one


or you know at the next support


resistance level maybe it's a you know


fair value gap if you know once price


taps into this and starts filling these


orders that's where I want to take


partial profits in case it does turn


around uh you know that you're securing


some of that you know or even do you


know a percentage you know once I'm at


you know profit of 25% or 50 or just


kind of whatever you kind of land on and


decide on. Then, you know, play around


with that to where you're taking some


profits but leaving one, you know, to


continue to maybe go in, you know, to


your uh take profit. Um, and I'll show


you I'll try to show you examples of


each of these. So,


I just randomly set uh two contracts in


gold and NAS. Uh so, there might not be


any rhyme or reason why I got in where I


got in, but I was just hoping that I


would be in profit on one of them to


show you guys. So, right now, of course,


I'm in two contracts.


um you know say if I it's not going to


be a necessarily one one but if you're


curious how to you know take partial


profits um you basically do it like a


pending


in the opposite direction. So, say if I


wanted to take partial profits whenever


price breaks the top of this wick, then


I would rightclick,


limit sell, and I would want to do one


contract cuz I'm in two contracts. Um,


so


whenever price gets up here, I want to


secure profits on


the one contract and then it will leave


the other contract to, you know,


continue on. So, we'll see if this


I probably, you know, just created a new


resistance, but okay. So you see that it


took profits from that one contract and


I am still in one contract. So that


might be, you know, a way for you to


um, you know, maybe eliminate just some


of that pressure that you might feel by


I've got to, you know, either close all


of it or sorry,


try to get this back up where I can see


it. Hey, you know, where it's I either


have to secure all of my profits


and close out the whole trade or, you


know, risk, you know, whatever your uh


stop-loss amount is and let it all go to


my takerit. So, you know that you can


sometimes put a lot of pressure on


yourself by feeling like those are your


only two options. And you know, so if


you maybe want to secure some profits to


just help your emotions and keep you a


little bit calm, then you know, maybe if


you go in with however many micro


contracts, if you're on micros,


um you know, like two, three, four


contracts, whatever it might be, taking


pro partial profit with like one or two


contracts. So you at least know no


matter what happens with that trade, you


at least took some profits and just kind


of see if that helps a little bit. And


of course if you are at like that say


one before you do take partial profits


then at that point you can maybe decide


if you want to move your stop loss to


break even. So, you know that you're,


you know, not risking any of your


capital, but you for sure just uh, you


know, secured some profits.


So, uh, you could try that. That's


probably one of my, um, other favorite


alternatives to do if I don't just move


my, you know, stop loss and stay in the


full contracts. Um, another thing that


you could do is a you know


structuralbased stops. So, um, you know,


move like don't move your stop loss up


as soon as it goes into profit. Um, you


know, or a little bit and you're like


immediately moving to break even or


that's what I've been doing.


maybe don't move your stop loss up until


it gets to, you know, a new structure.


So whether that be if you're you know in


a buy in a bullish trend and you see a


higher low then you know maybe decide


then okay once it breaks this structure


then I am okay with moving my stop loss


up you know and whether that be to break


even um you know whatever you want to


do. I personally will not move my stop


loss up unless I'm moving it to break


even. Um, you know, so you could


see if I can maybe find a quick example


of kind of what I'm talking about. So,


so say if we, you know, are in this


trade, I'll use it as an example, and


say I don't want to move my stop loss up


until price hits, you know, above


u this, you know, so that once it breaks


that structure, then I can move my stop


loss to break even, you know kind of


depending on like where your entry is


and you know if you have like another


fractal maybe like right here to where


we are at least to break even then you


know at that point once it breaks this


structure then I know that I'm safe to


go ahead and move up to at least break


even. So you know that's another thing


you could try whether it be break of


structure


you know a fractal once a new higher low


fractal forms


maybe decide then you know that okay I


can go ahead and move it to break even


but just kind of you know use the


you know structure to um you know


determine when to move that. So, you're


basing it off of price action and not


necessarily just feeling like it's a


guessing game of, well, I'm $10 in


profit. Let me go ahead and move to


break even. So, you're actually using


price action


to determine when and where to move it.


Um, another thing is, of course,


trailing your stop-loss. Um, I used to


always love to do this and I still will


do it every once in a while depending on


how um I guess how soon I move my stop


loss. But um you know say once you


secure profits maybe at that one one


where you're doing the you know partial


um you know or whatever you decide if


it's a one to two whatever you kind of


decide at the beginning of the trade I


would definitely make the decision


before you even get into the trade. That


way you're not, you know, maybe


incorporating some of the emotions by


seeing if you're, you know, in the green


or if you're in negative. You just


already know before you even get in the


trade what your plan is. It'll help you


kind of stick with it a little bit more.


Um so yeah say if once your chart gets


to a one one and


whether you take partial profits or not


but just you know if you say to yourself


okay once price gets to a one one I will


then move my stop loss to break even but


then I will start trailing it. So you're


not, you know, hopefully you're not


really close to uh current price. So


there's enough room for some


fluctuations and little pullbacks. Um


but as price continues on in your


direction, then it's just automatically


trailing behind it. Um,


and of course, if you're not sure how to


do that, um, you can


let me get down here


and let's go ahead and set this up.


Okay. So, say if I moved this to


about break even


and then I want to trail it


and say I want to do


say 10


ticks.


So, that's how far I want to trell it.


And then try see trying to remember if


it'll let me do it once I'm already in


the trade.


I just went blank on that. I'm going to


hit it. May just buy me in two more.


Nope, it didn't. Okay.


Yeah. So I think once price


comes up and you know continues in


profit.


>> Okay. No, it did. I think it did buy me


into another one.


Okay. So you may have to play with that


one. You may have to do that before you


get in the trade. Um but we'll see if it


may stop me out now. But if it does


continue to go up, you'll see


that price will start trailing it by the


10 ticks.


Okay, we'll check on that in a minute


just so we don't run out of time.


And I'll check my notes also to see if


um because I was thinking that you could


do that once you were already in the


trade, but I might also be thinking of a


different platform. So I'll check on


that one.


Um and then of course


>> another one is you could do you know say


core versus runner. So it's it kind of


incorporates some of the other ones, but


say if you initially always go in with


four micros uh you know two micros, four


micros, whatever it is,


but you split those up. So, you know,


say two of them, you take profit at a


one one


um you know, or whatever you your kind


of predetermined


um risk-to-reward is. And so, you


decide, I'm going to take profit at say


a one and then the stop loss I'm going


to move up to break even. And then the


other two I'm just going to leave. I'm


going to leave my stop loss at break


even.


And then I'm going to leave my take


profit where it initially was. So you've


taken, you know, two u two of those


micros. You've taken profit once it hit


the one one. So you've made profit, you


know, secured on the trade and your stop


loss is protected because now you've


moved the other two to break even. And


then you just let it go. Whether that be


walk away, don't look at the chart,


close your computer, uh go do whatever


because it's risk-free and you're not


watching it to maybe like micromanage.


If you start seeing those pullbacks and


you know the emotions start coming into


play and it's like, "Oh, let me move my


stop loss up a little bit more."


Excuse me. and you know, so it just kind


of makes it to where you just take some


of those emotions out. So, um, you know,


you could try that as well and see if


you know, it does hit that takerit. Then


that'll almost build up some of that


confidence on okay trades are good. Once


I see my setup and I see my confluences


and I stick with them,


then I'm going to set my takerit and my


stop loss and I'm just going to leave it


and you know maybe set alerts at a one


one. So then you can open up your chart


and decide from there if you know if you


want to set that partial profit u you


know kind of go from there. But um but I


think with leaving two of those running


it can kind of slowly build up that


confidence


especially the last few months how


they've been. I know a lot of us are


really gunshy with just setting a


takerit and leaving it


because we've gotten wicked out so many


times with just how volatile and


unpredictable the markets have been the


last you know I don't know 2 3 months.


Um, so slowly by doing that and seeing


that it's okay to not move a stop loss,


it'll just kind of build up that


confidence a little bit.


So try those and like I said, you can


either back test some of these ideas or


even hop into your practice account and,


you know, just kind of see which one you


like best. Um, you know, if you're kind


of getting to the point to where you are


getting a little bit frustrated from,


you know, moving your stop loss up and


then you go back and check it and it


came back and it hit your stop loss and


then it went right back up to where your


initial take profit was. I know that's


also frustrating. So just maybe play


around with some other ideas and see if


you know if you like any of them and if


if you do which one you like and then


kind of the same thing stick with that


for a couple of weeks and give it you


know a good good chance and and then


kind of decide okay I don't like that


one now I'm gonna move to trailing my


stop loss and seeing if I like that


or just kind of what your profit, you


know, ratio is by doing each one. And


like always, journal whichever one you


try and, you know, that way you can


always go back and and compare.


Okay. So, does anybody have any


questions


um


before we kind of move on to the next


thing?


Okay. Um,


one other thing I wanted to show y'all


before I call somebody up, and I know


we're probably running a little bit


late, but um, but I wanted to show y'all


my little bull bear


thing that my sister made. So, I don't


remember who initially shared this in


circle,


but I sent that to my sister and I was


like, "Please learn how to make this and


uh, make one." So, I'll post it in


Circle. There's another one that she


made me, but I I don't want to show it


on the call cuz I feel like it needs to


be more in the unhinged area. But um but


I'll share that and then if you guys


want any um


she'll be on there. I'll tag my sister


and she can maybe make some. Um, okay.


So, now we are going to uh


switch gears and we are going to have


somebody hopefully uh come off mute and


hopefully share your screen. Um, sorry,


I'm just going to check.


Um,


yeah. So hopefully you can share your


screen and just kind of talk us through


maybe what trades you've taken or what


trades you're looking into taking, what


your, you know, your BFF pair is, which


one you're kind of sticking with, what


confluence is, all the good stuff. Um,


so I don't know if I'm trying to look in


the participants to see if Joy, are you


still on the call?


And if you are


>> I am I am but I don't have a screen to


share because of passing my challenge


last night or yesterday.


>> Oh


>> I haven't activated the new account yet.


>> Okay. Um and that's fine. Um, do you


have and we can either go through it


like looking at my chart


or if you would rather like wait until


you have all that set up and then we can


like you know maybe do that on another


uh another call if you would rather like


share your screen and show it that way.


>> Sure. Cuz I don't really have anything


to share right now.


>> Okay.


I didn't know this, but when you pass


the combine, it like wipes out your


account and my whole screen went black


and it said you have no active accounts.


So, I'm like,


>> "Oh,


>> yeah." I'm like, "What does that mean?"


I thought it was doing like a twostep.


It was,


>> you know, that top acts weird.


>> Yeah. I texted a picture to Ellie and


she's like, "Oh, no. That's normal. That


means you passed." And I'm like, "Oh,


okay." because I was going to have to


try and lose some money because


>> all you went over.


>> Yeah. So, um and then it wiped out my


account and now I can't access any of


the information.


>> Okay. Does it even take away your


practice?


>> Yeah. I can't even log into it on the


new dashboard.


>> Oh, wow.


>> Yeah.


>> Well, that's okay. So, we'll congrats


again, by the way. Thank you.


>> And we'll come back. We'll come back to


you. Um, so I'm just going to kind of


keep going through and y'all let me know


if uh Tatum, are you around the baby or


can you come off mute?


>> I'm here.


>> Okay.


>> Are you able to to share your screen?


>> Yeah.


>> Okay. So, I'm going to um I'm going to


make you a co-host


and then I think with me doing that


I think you can uh share your screen.


>> Okay.


>> So, see if it gave you like a message


>> to maybe accept co-host.


>> I'm on my phone, so just


bear with me.


See


Okay. I don't see anything.


Oh, wait.


Screen share.


>> Uh, yes. Try try that.


Share screen.


>> He's like, "Here, I'll help."


>> He's been all morning.


We'll stop other screen sharing. Do you


want to continue? Yes.


There we go. Okay,


>> this is where I'm at.


Move your face.


>> Nice. Okay, gold. Let me get my pulled


up over here. Let's see. Five minute.


Okay, so what what confluences are you


are you like sticking with again?


um the W EMAs cross


um higher highs and then also I like to


watch the higher time frames to see if


it needs pulling back to the 9 EMA. See


how it touched here?


>> Yes. And then


oops not 30 minute.


>> It gets pretty far away from that 9 EMA.


It's she wants to come back and touch it


a lot of the times. So watch for that.


And


now I just wait.


I took this with you morning. Um I got


in at market actually which if I were in


my combine I probably wouldn't have done


this but


I wanted to know or I I wanted to get


into something before I made a bad


decision in my combine.


>> Yeah, I get that. Yeah, get it out of


the way on the practice account.


>> And let's see. I took


>> everybody close your eyes.


>> Yeah. Sorry.


>> Might see a titty photo.


>> Remember if I


Sorry, y'all. There's the


>> No, you're fine.


>> I don't think I took a screenshot of it.


>> I got into one last night a sale and


it was just it wasn't far enough on the


five minute


for me to


get into.


Yeah. Okay.


>> And and so I I saw it reversing then I


got into a buy. I think it was it was


close to here in this area and then of


course it just


stuck


and


finally I guess it broke out in the


middle of the night but I ended up


closing it I think at


um maybe break even.


Yeah, I like that. I mean, and


what are you in? Yeah, you're like


almostundred and what is your profitund


is it? Is that $150?


>> Yeah.


>> Yeah. And then your uh limit sale is


that are you doing a partial?


>> Okay.


>> Yeah.


>> Yeah. I like that. I think that's


>> it. hit my TP up there.


>> Yeah, it did.


>> Well, it's like our entries like our


entries and our take profits are like


they create new resistance.


>> Okay. Well, I like I love it. I like


your of course your confluences.


Um and you know even using the like


higher time frame bias and cuz obviously


I do like the same thing. If I see that


price has just been going and going I'm


like surely we're going to have a


pullback. So, um, yeah, I think that's I


think that's awesome to be able to,


um, you know, use all of those to make


your decision.


>> Yep.


>> So, yeah, good job. Thank you.


>> Thanks.


>> Okay. Uh, how do I do this?


>> Let me um


>> Did you end it on yours?


>> I stopped. Okay. game live broadcast has


stopped due to you have stopped screen


sharing. Okay.


>> Okay. Awesome. Let me see. Yeah, cuz it


will


Yeah. Can y'all see my screen now?


>> Yes.


>> Okay. Well, that was easy. Now we know


the easy way to do that. Um Okay. Yeah.


So, awesome. Does anybody have any


questions with


what um like Tatum's confluences and


I feel like for the most part,


she uses a lot of the ones that, you


know, a lot of us use. So, um,


so hopefully y'all can see how it worked


out for her to wait. And


>> can I ask the question?


>> Yes.


>> Um, it looked like you had two contracts


and then two contracts maybe on top of


that. Is that where you added up to


four?


No, ma'am. I


So, that was my stop loss that you


probably saw just into profit.


>> Gotcha. Gotcha. Gotcha. Okay. Thank you.


I need to learn how to use my phone.


That looked awesome. I didn't know it


could do all those things.


>> It definitely um


a pain in the neck, but uh right now


that's what I'm having to do. So,


>> yeah, it's okay. It look great to me and


it makes it very mobile. Yep.


>> Yeah. And you'll get to where like a lot


of times if I'm in my office, I'll like


set up my trades but then you know kind


of monitor them, you know, probably like


Tatum like where you're not having to


sit with a computer. Uh, but I get to


where I almost prefer to trade on my


phone


>> than like come in the office and and I


know that my hands like I'm going to get


in like 10 years and like I'm going to


have like all kind of like arthritis in


my hands and cuz it's just such a small


screen. But um but yeah, it's just so


much so much better I think to for me


anyways to not have to sit in my office.


So um okay guys, well


if y'all don't have any questions for,


you know, kind of different options on


not always having to feel like you just


have to move your stop loss up. Then um


then we'll just go ahead and


end in the call. Um if y'all have any


questions for me or anything with you


know that Tatum had shared then


yeah of course just let me know in


circle if um


if you have any questions once you start


kind of playing around with that. Um


again I'll check on that trailing stop.


um


cuz I do feel like I've done that once


I'm in a trade, but again, I might be


getting it confused with something else.


So, um


>> so yeah, just play around with it and


let me know once you do which one you


kind of stick with and um and we'll kind


of go from there. See what who gets


called up next week and see what they're


doing. Um all right, guys. Well, if


y'all don't have any questions, then I


will see you guys tonight on the live


Zoom call if you're able to join with


us. All right, guys. Well, y'all have a


good day and I'll talk to you later. All


right. Bye.$video_15_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_15_summary$This lesson walks through different ways to take profit and how to choose the one that fits the setup. Shea shows practical exit choices so you can stop treating profit-taking like guesswork.$video_15_summary$
      ELSE summary
    END
WHERE sort_order = 15
  AND title = $title_15$Taking Profit Options$title_15$;

-- Backfill watch-page content for lesson 16: Liquidity & Stop Placement
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_16_transcript$Okay. So, you can kind of see.


Hey, look how close. Like, tell me they


are not watching what I was doing. It


just was right there. So, like normally


if I was in a trade like on my real


account, um depending on where I got in,


you know, moved my stop loss and all


that, I would have just taken profit.


Like I wouldn't let that move come all


the way back down this far. Um but just


for this one, I just wanted to kind of


leave it. So, okay, let me get up to to


my notes. So yeah, today um again I want


to talk about like liquidity, the


difference between outside liquidity,


inside liquidity. If you ever you know


hear me saying maybe uh buy side


liquidity or you know it's heading


toward or just took out some outside


liquidity or anything like that. If you


ever hear anybody say that, um, I just


kind of want to go over, you know, a


little bit more of what I mean by that


and how you can kind of um, learn to use


it for your benefit as far as making


sure that your stop loss is maybe out


far enough to where you don't get


trapped in those liquidity grabs. Um, so


like on my live scalping call, this


would be a good one if you want to take


a shot. Every time I say liquidity,


this is the call to do it. So, um, but


yeah, if you ever feel like, you know,


like I was just saying, the, you know,


the big people like they know where my


take profit was. Like that's why it got


right up to it and then stopped. And


then sometimes you kind of feel that


with your stop loss where it's like they


get, you know, it comes up and it barely


wicks you out and then goes right back


in your direction and goes to where your


takerit is. Um, and so if you ever feel


like they know where your stop losses


are, uh, it's because they do. And


you know, they just they know what we


look at. They know where, you know, we


want to set our stop loss. So, it's a


short enough stop-loss to where we get


maximum profits, but at the same time,


we feel like it's in a safe zone. And


they know where our zones are. So,


that's where they want to go and, you


know, grab those liquidity grabs and


then go back in, you know, that


direction.


So, um,


of course, if you ever hear, you know,


buyside liquidity versus sellside


liquidity, buy side is just it's going


to be at say your 4hour resistance. So,


it's going to be up at the top above


recent high. Um, you know, so, and then


of course sell side is just the


opposite. It's going to be maybe like


your 4hour support level.


um you know, so they're going to go grab


that liquidity, the sell side liquidity,


and then go right back up. Um inside


liquidity, and then I'll show you


examples as well, but inside liquidity


is just liquidity within a range. So it


would be say inside of my 4hour support


and resistance. So we're inside I have a


big box. any liquidity grabs inside are


going to be the you know fair value gaps


that are inside there


any like consolidation some the you know


if it's just ranging um those are like


you know prime


like gold mine um you know of resting


order. So they will go and take out


those uh inside liquidity grabs in like


those types of ranges. Um and then of


course outside liquidity will be the


liquidity beyond the range boundary. So


that's either you know previous day high


low session high lows um you know


support and resistance things like that


like kind of your your broader area uh


higher time frames you know of course


like our 4hour our 1 hour things like


that. Um but those are kind of outside


liquidity grabs.


um price tends to clear inside liquidity


first then runs for the outside areas.


So that's why you know either a um kind


of a consolidation zone that's say


inside your 4hour support and resistance


they'll kind of go and fill all of those


orders first uh fair value gaps things


like that. So they'll grab all of that


inside liquidity grab before they go,


you know, to the 4 hour for instance,


they resistance area. So if you want to


think of it as like the inside is


they're getting all their, you know,


eating appetizers and then the outside


is kind of the main course. So the


inside can, you know, sometimes give


early warning signs for a larger move.


So, you know, depending on if you see a,


you know, a sellside liquidity grab with


a fair value gap or something like that


on the inside then and then it goes up,


then that's a good, you know, sign that


you can kind of start watching for that.


Okay, now I see that it grabbed the, you


know, sellside liquidity and it's going


back up. So it looks like it's heading


to say my 4hour resistance.


So you can kind of watch and learn


kind of what they are doing on their end


and it helps you kind of decide what


what you want to do you know on our


side. um you know


I want to get into a buy for instance


and that's kind of where like all your


other confluences come into play.


Um okay so I kind of and my lines are


going to be off of course because


they're too present but um but I wanted


to kind of just show some examples of


each one of these. So um let's just


ignore this over here. I was hoping it


would be gone and then it' be like,


"Yay, hit take profit." But um okay, so


this right here.


Okay. So even if you know we say that


this


um you know resistance area was still


around the same zone. So, and then you


see


price came up and wicked above this


resistance line.


That's a buy side liquidity because it


broke above the the high


and then we reverse.


Um, jump over and show you sellside


liquidity. So, same right here. sellside


liquidity


comes down, wicks below the low and then


we go up. So that's all that refers to.


If you ever hear me or anybody else say


buy side, sell side liquidity, it's


just, you know, it's just if we're at


the bottom or if we're at the top, you


know, sell side wicks down, then usually


goes up into a buy.


um inside liquidity.


So of course fair value gap


you know so if you see this


and then price comes up


and wicks


and then of course comes back down


because it's a a u bearish fair value


gap. So this would be considered inside


liquidity


because of course it's inside


my support and resistance


which you know that can either be of


course my 4 hour I just kind of go off


of um it's not always like previous days


high but um but you know it's based on


the higher time frame. So the higher


time frame bias is what gets you your,


you know, your ceiling and your floor


support and resistance. So any kind of


liquidity grab inside that area is just


going to be a an inside liquidity. Um,


so I'll try to see if I can find


for instance


what we look for as far as break of


structure


is al can also be a liquidity grab area.


Trying to see if I can find one that


maybe to use as an example.


So, say right here we're watching this


consolidation right here


and


we want to


wait for,


you know, a break of structure to know


maybe that we're going to get into a


cell, you know, using this right here as


an example. So, we want it to break


below my crosshairs right here.


And of course price did break below it.


So if we would have immediately gotten


to a sell like just based on that then


you know they they kind of know that for


one it's below my support but you know


they're like okay they're just going to


wait for the break of structure and then


they're going to get into a cell because


they're going to think that's where it's


going. So they come in, give a little


wick and you know stop


stop everybody out possibly


um you know or not initially trigger


everybody in and then you know once


you're triggered in say we have our stop


loss


I don't know maybe I know some would


maybe go pretty close but you know if


our lines were where they were, we would


either make sure we were above this


caution one or even if it was above this


one hour and we wanted a lot more


cushion.


Then once they know everybody's


triggered in, they go back in their


intended direction, stop everybody out.


So you just kind of want to, you know,


and of course that's where we also want


to make sure that we have all of our


other confluences there. Um, you know,


me personally, if this broke below, I


wouldn't immediately get in that


anyways. just with it being, you know,


at my 4hour support, I would want, you


know, a couple of tests,


uh, you know, to either form my, you


know, M or my W and then kind of go from


there. So, um, you know, that's where


it's really important to


wait for all of your confluences to be


there. And,


you know, if they are and you get in and


you still get stopped out, then that's


where we just know we did everything


that we possibly could to make sure


that, you know, we're


we we felt pretty confident in getting


in that trade. Um, so


of course to kind of help you on where


to place your stop loss, it's kind of


where we, you know, already try to and I


know it's


a lot larger. Like I know there's a lot


of traders, especially if they're


scalping, where they want a really


small,


uh, stop-loss. Uh, so their, you know,


profits are larger, but I feel like, you


know, like some, I know if they get in,


well, we use a fair value gap. I know a


fair value gap's a big one, but


um, you know, I mean, their stop loss


might be just right at like the tip of


the box. And


I always feel like if I'm, you know,


setting my stop loss, even if I was


getting in based on this, you know, fill


of this fair value gap and I see, okay,


price came up, filled the orders, now


we're going back down, you know,


possibly to this 4hour support,


I would not just place my stop loss, you


know, right right above this. um you


know, seeing that it's right at this 1


hour uh resistance area, I would


definitely feel a lot better because


both of those are telling me, okay,


we're bouncing off. We're going to go


back down. But that's where I always


feel more comfortable placing it above


that previous high,


you know, which would be about up here.


And even though it's a larger stop-loss,


I feel like


most of the time it's safe.


If for some reason it does come and hit


my stop loss, it's usually reversing. I


mean, we're usually going to, you know,


it's


not going to say it never happens cuz it


definitely does where a wick will just


come right up here, wick me out, and


then go right back down. But most of the


time, you know, if price were to come up


to this area where my stop loss was,


more than likely it's coming back up to,


you know, either this 15minute or we're


coming back up to this 4hour resistance.


So, you know, I feel like I was going to


get I would get stopped out anyways. Uh,


but at least if there's any, you know,


little pullbacks, I'm usually pretty


safe by doing that previous high and not


just right above, you know, say the


resistance area or fair value gap or


anything like that just because I know


that they hunt for those stop losses in


in those areas. And you know, I feel


like a lot of times if you know, I'm


wanting to get into a trade and um you


know, it


like maybe say this for instance,


you know, say I get in and you know,


it's looking really good, really good,


and then of course comes right back


down. if I would have had my stop loss


right below this, you know, little


caution area that I had, you know, comes


down, wakes me out, and comes right back


up. So,


there are times where I know I feel like


if it's being


too polite, it may be a trap. And so, I


will be like a little cautious, I guess.


Um,


I guess depending on where I get in,


where my stop loss is, what I'm trading,


you know, if I'm trading NAS or uh,


gold, something like that, where I know


they can be pretty volatile, then, yeah,


I'm just a little more


cautious. But um


especially with with NAS is if I feel


like it's going too smoothly


um you know maybe


maybe something like this where it's


just you know it just looks so nice and


you know like you want it to look then


it's like what's going on


because you're usually not that nice.


Um, so yeah, just be careful with um,


you know, placing


your stop losses too close uh because


they they will hunt for those. Um,


yeah. So that's pretty much


like the basics to buy side, sell side


liquidity,


inside liquidity versus outside


liquidity.


Um, you know, just just remember a lot


of times they try to grab inside before


they make the big moves, which is a lot


of times why you see this, you know,


it's just hunting stop orders. So, you


know, I know there's even times that if


it's consolidated and it's I guess


ranging in a big enough zone,


so you know, say if it's going from this


4 hour, you know, to the 1 hour, things


like that, like there's quite a bit of


room for


possibly maybe like a onetoone kind of


situation.


I will write, you know, be okay getting


in, writing it up, writing it down, up,


down, all of that. Uh, they know that


scalpers a lot of times will do that,


especially if they're trading the one


minute time frame where you can, you


know, really kind of see that up and


down.


They will hunt, you know, they will


shoot these little wicks right here, you


know, because they know most people will


have their stop losses just right above,


you know, this support. So, you know,


you kind of see it kind of comes down


wicks, goes back up. That one didn't


necessarily do it, but you know, this


little wick, this is probably the area


of like it's playing nice. What? Why is


it doing that?


And then so it it kind of makes you feel


a little more comfortable of getting in


and trying it again and then it does it


again. Stops you right back out. Uh so


you know those


inside areas if you ever choose to


trade, you know, the kind of ranging


areas. H just really be careful with


your stop losses because they love to,


you know, grab those stop losses in


those ranges. And then of course once


they do that enough, then that's where,


you know, whenever they're kind of done


having fun


in this area, then,


you know, you start seeing


that maybe we're going to


make a bigger move. Uh which you know


usually wait for break a structure which


whichever kind of uh area you're looking


for depending on what time frame you're


on. So, you know, if you're waiting for


a break of structure, then once you see


that, it's like, okay, maybe we're going


to get out of this range and finally


make a big move. And you know, of


course, for me, if I was to get in when


I saw this break structure of this right


here,


I would have my stop loss somewhere


below this area. And you know, so you


see the EMAs cross the higher highs, you


know, you just kind of start watching


for your confluences to kind of know,


okay, it's it is moving. We're finally


done with, you know, grabbing all the


liquidity grabs in this inside


zone, inside liquidity, and maybe we are


now going to, you know, make a big move.


You know, we kind of ranged, we had


sellside liquidity,


had sellside liquidity, and then you can


see price started moving back up. So,


you know, if you just have your stop


losses,


you know, above previous highs or just


outside of maybe like that sellside


liquidity, then you're usually a lot


safer uh than than maybe you would be if


you just put it, you know, a really


short stop-loss. And I don't think I've


ever


done a really small stop loss that I can


ever think of. Um


I think I have always done probably a


lot larger than I should have. But um


but yeah, I just feel like it


I don't know. it just is a lot safer for


me and especially with um me trading NAS


crypto


things like that that are, you know, not


very


nice sometimes with liquidity grabs.


It's just kind of gotten me in that


habit of I would rather have a little


bit of a stop loss that's, you know, a


little further away and know that I'm a


little more protected. So,


um, yeah. So, that's kind of how you can


use the liquidity grabs in your favor


with stop losses. You know, of course,


take profits are the same way, you know,


just outside of this range. And, you


know, hopefully that kind of helps a


little bit with


placing your stop loss in a little bit


of a safer area.


So, with all of that being said, does


anybody have any questions about


anything with liquidity or liquidity


grabs or anything like that?


And while I'm waiting, I'm just going to


peek and see what


what Nas is doing. Yeah, I'm going to


see if my little simple mind can can get


what you're saying because I'm still


taking in visually if this is okay. Tell


me if I'm like oversimplifying.


>> No, you're fine. I'll get back over


here.


>> Like some of these liquidity sweeps like


we can't be fooled that it's actually


going in that direction. Like it's like


a fake out. So the sweep is essentially


telling you


or or is it telling you it will go back


in that way just once it takes people's


stock loss like what's the simple way to


think about it?


>> Yeah. So liquidity grabs are usually you


know they're they are stopping people


out. They're grabbing those stop orders


so they can go in the opposite


direction.


So, they're going to knock all of these


people out, you know, for instance, say


if say if everybody was in,


I don't know, a buy. I'm trying to see


where maybe they would have gotten


gotten trapped. Say if you know,


somebody saw this and they were like,


"Okay, I'm going to get into a buy." And


so, you know, they see all of these stop


stop-loss orders down in this area. So,


they're going to knock all these people


out, which of course is going to make


it, you know, cheaper for them. So, then


they're going to buy all these orders


and of course it's going to increase


price. And then once they get up here


and they've made all this money because


now it's more expensive, then they're


going to do the same thing. They're


going to, you know, knock all these


people out and then they're going to


sell and, you know, so that's where a


lot of times the liquidity grabs are,


you know, grabs liquidity and then goes


in the opposite direction. So definitely


it's a fake out most of the time. I you


know they either want to fake people out


on that it's going in you know a sell


direction


and then it doesn't it goes back up. Um


you know so yeah essentially fake out


when you see a liquidity grab a lot of


times it's going to go in the opposite


direction.


Okay, that helped because I think before


I used to when I get knocked out by


liquidity, I would think, damn, I saw


the chart totally wrong. I should have


had my order in the other way. And then


it flips back again the other way. And


then I'm like, oh my god, I'm wrong


again. And I think it caused me so much


confusion, but essentially if I have my


order going away and I see liquidity


sweep, it's kind of telling me I'm I am


right


>> because they're trying to knock people


out just to keep it going in the same


direction.


>> Yes.


>> Thank you.


>> Yeah. So, if you're already in a buy,


say like down here, and then you see,


you know, like this, like a sharp, you


know, just a quick wick or, you know,


one candle and then that's it. And a lot


of times, like these little wicks right


here,


>> Mhm.,


>> you know, are like liquidity grabs,


especially if it's in like a zone like


this. I so yeah if you see something


like this then it's like okay price may


be continuing to go back up. Um you know


so that's where


yeah you can definitely kind of use it


if you're already in a trade to know


that the price is probably going to keep


going in your direction. you know, as


long as it didn't say like come down and


create like a lower low, you know, or


something like that, which


>> you know, if you see like opposite


confluences, then you know, a lot of


times we know we can just close out of


the trade. Um, you know, or really trail


your stop loss, like


you know, cuz it may be reversing. But,


um, but yeah. Yeah. A lot of times when


you see those liquidity grabs, it will,


you know, be a good indication that it's


going to go in the opposite direction.


>> I think that's why I had to take a break


from NAS for a while because it was so


wiky and so volatile for a while that it


had me upside down in my brain like, "Oh


my god, I don't know anything. I thought


I was getting this."


>> I know. Yeah, I agree. And ex especially


with NAS like NAS and gold I think are


like the top two that will definitely at


times make you feel like you're going


crazy because like I don't know how many


times I've gotten tricked by it. You


know, like if I see this and you know,


I'm like, "Oh, okay. We got breakage


structure, we got EMA cross, we got


higher highs, higher low, get into it."


And then it's like, "No, it either


immediately will start ranging and or


worse, you know, do something like this


and make you start seeing confluences


that are telling you it's reversing."


But then it just, you know, it just


constantly, it's like one thing after


another. It's like, "Oh, no reversing.


Do I need to get into a sale?" And it's


like, "Oh, we're chopping." Okay. Oh,


what are we doing here? We're breaking


structure. Nope. Now we're It's like,


but I feel like especially with NAS, if


it ever gets to where


I just feel like I cannot make a clear


decision or I'm uh changing my bias


every five minutes, every new candle,


I'm like, "Oh, there we go. It's going


into a, you know, now we're in a buy


trend." And then like the next candle


I'm like, "No, actually I see an M and I


think we're going in a downward trend."


And like if I ever catch myself doing


that, I'm like, "Stay out of it cuz


>> you don't know where the hell it's going


right now." And you just prove that to


yourself. So yeah, I feel like if I ever


question that with Naz. Um because if


not I've done what you know you were


saying and I will like sell buy sell by


buy and I'm like opposite every time of


what like I get into a sale and it


knocks me out cuz it's going into a buy


then I get into a buy and it you know


and it just can be it can be nasty


sometimes which is why sometimes I call


her nasty but


it definitely knows knows what I don't


know how but they know and probably cuz


the you know like the bigger traders


used to be like little retail traders


like us so they just they know probably


how a lot of us think and


yeah I'm sure once they get to that that


level they some of them probably have a


lot of fun with us but


I think that's like the DOM and stuff


comes in too, how some people use the


DOM, which I've been trying to figure


out because you can see how many orders


are sitting there.


>> Yes.


>> But um I also appreciate you saying


stuff about bigger stop losses, but


because since I kept getting knocked out


of things anyways, you know, the allure


of some scalpers of making this tiny


little stop loss and then look, they


have a 1 to 10 and I'm like, I'm getting


stopped out anyways. I might as well,


you know, do that. And then that was not


good either.


>> I know. Yeah, I I agree.


Yeah, cuz I definitely see some of them


and I'm like, what? Like that is such a


small,


you know, stop loss. and and I know a


lot of them it is because they want that


profit a lot quicker and it you know


makes that one one shorter but


I don't know I mean I know a lot of


times it works for them like especially


the ones that just trade on you know


break a structure


inverse fair value gap all that stuff


but I don't know I feel like I have


gotten burned so many times to where


I uh I don't know. I think maybe it's


just to calm like anxiety. So, I don't


get anxious whenever I trade. I try to


just eliminate that. Anything that's


probably ever caused me anxiety,


I've either adjusted it, changed it, or


completely eliminated it cuz I I'm like,


I never want to fill that again. And the


smaller stop loss is probably one of


those that happened really early on for


me. So,


yeah, I I always have a larger stop


stop loss. Thank you so much.


>> You're welcome.


>> I can show y'all a visual that helps me.


>> Uh yeah, definitely. If you want to


throw that in circle,


that way, you know, we can all see that,


that would be great.


>> There's a study called TTM


LRC, and basically it's just a


regression line,


and it has five lines.


and and you can literally just kind of


get the trend and it trades up and then


it trades back down and then but if the


line is going up


it kind of tells you there there's your


stop runs but it's just called a


regression line. You can probably look


it up,


>> okay?


>> Cuz there's, you know, there's so many


five deva standard deviations


or whatever, but it gives you trend.


And if you watch it all day, you can


say, well,


it's going between the two lines instead


of the five lines.


And if I keep my stop below there, I may


be able to stay in a trade.


But while you were to while you were


talking, I made two trades. I made with


no stop. 35 bucks.


>> Nice.


>> $45 on in it or the small NAS.


>> But then I put then I put a stop in. You


know, I get five bucks just to get my


>> thing back,


>> right?


>> It works. But I'm a rule breaker. I know


you y'all can all make fun of me.


>> Oh, no.


>> But I love that regression line for what


she was saying. And I'm trying She's


trying to visualize what you're


explaining.


>> Yeah.


>> And I think that's a really good visual


tool.


>> Okay.


>> I don't want to confuse anybody either.


So I tell me, "Hey, quit putting that


crap in there cuz I don't want to


confuse what you're trying to teach."


And I just thought that that's great.


That's that's a great


>> If it works for you, that's amazing. I


know just if like whenever I look at


your chart, I'm just like, "Oh god.


That's just it's just I think it's a


personal preference cuz I like my


charts, you know, and some may look at


my charts with my, you know, my 1 hour,


my 15 minute, my like all my lines and


just be like, "Oh my god, that's so


busy." But so I know everybody's version


of a clean chart and a busy chart is


different, but yeah, I mean, no, I say


if it if it works for you, go for it.


Francis, I was going to answer your


question. You're asking when I'm trading


10 contracts on minis


if I still use a wide bracket order and


if so, how do I manage the pullbacks


emotionally?


Um, a lot of times I either just will


not watch it and just set my alerts,


whether that's,


you know, if I have to hop on to my


Trade Locker or Trading View, one of


those two that will allow alerts, then


I'll just set the alerts. So, I usually


will set them if like here, I'll kind of


use this as an example.


So,


and I don't know why I always want to


know this, but I like just do. Um, so if


I didn't have my stop loss pulled up and


say say my stop loss was at this 1 hour


resistance. So entry here, take profit,


stop loss here, I would set an alert


about halfway


almost just to let me know like we're


heading towards your stop loss. That's


one I don't even know why I do that. I


don't know why I want to know that, but


I do. And um so I either just


don't watch it um and of course I'll do


the same thing with my alerts. I'll set


an alert about, you know, maybe


halfwayish.


Um, and then that way if that alert goes


off, I know, okay, I'm halfway between


my entry and my take profit, maybe I


will go ahead and move my stop loss, you


know, to break even. Um, but yeah, I


feel like most of the time I just


I know that if it does hit my stop loss,


it's not going to either u breach me if


I'm doing it in a a challenge account,


I'm not going to lose, you know, all of


my money, you know, depending on what


account I'm trading in.


I know that I'm not going to lose the


account


if it hits that stop loss. Um, if I,


you know, maybe set it and then where I


want my stop loss is


too large where maybe I may lose my


account or breach a challenge account if


it were to hit that then, you know,


that's where I will adjust it. I will,


you know, instead of maybe my stop loss


being down here, I may have to move it


up here. And I hate if that happens


because I don't feel like it's very


safe. But that's where I think


you know if you trade maybe the same


number of contracts


um you'll kind of just know visually


okay from if my entry is here and I want


my stop loss here which you know say


what would that be roughly a 100red


ticks away


I know that this amount, this distance


right here, my stop loss is good with


the dollar amount that I want to risk.


So, you know, you'll either kind of get


to where you learn that distance and


what that uh stop-loss amount will be.


Um, and of course like you know this new


OCO bracket uh thing that they've


started you know you can you can kind of


play with that a little bit. Um, you


know, so there's different ways I guess


to like manage the emotions with a


pullback, but for sure the biggest one


is whatever your stop loss is, make sure


you will not lose your account if it


hits that. And


and I think a lot of times that's


probably like the biggest thing that


helps helps with my emotions. Um because


yeah, whenever I am trading with the 10


contracts and of course I only do that


if I'm trying to pass the challenge, but


I mean the stop loss is, you know, it's


a pretty good chunk if it were to hit


that. Um,


which is probably another reason why


depending on what account I'm in, but


especially if I'm trying to pass that


challenge and I know I'm going like all


in with, you know, 10 or 11 contracts,


I will, you know, I tend to move my stop


loss up pretty quickly. And, you know,


sometimes I get knocked out pretty quick


and that's okay. I just get right back


in. But um but I am a lot more careful


with my stop loss when I'm going in with


10 10 minis.


When you're doing your futures, aren't


you just risking the price of the


contract? So setting a wide stop loss


could be a large loss.


I want to make sure I'm understanding


that.


I so yeah definitely setting a wide stop


loss is a larger loss


because it you know I was trying to


think I think there was a


thing in the resources tab let me let me


look over here just really quick


cuz I don't remember who put it in here.


Yeah, I think this futures calculator


like you can put in there,


you know, how much you want to risk and


yeah, it's like,


you know, whatever it is, like one tick


is, you know, so much or whatever,


something like that. Um I can't think


exactly what it is but yeah so the more


you know or the further your stop loss


is of course it's you know


getting you know further away um you


know with however many contracts you buy


into.


I don't know if I answered that at all,


but


but yeah, definitely it is a larger loss


the further your stop loss is away.


Well, this thing just keeps keeps


playing with that stop loss. Just keeps


going back and forth.


All right, guys. Well, if y'all don't


have any more questions regarding this,


then I will go ahead and hop off. And of


course, if you, you know, are watching


this at a at a later date or time and


um, you know, or even if you're on the


call and you kind of think of a question


later on or get into a trade and


something happens with liquidity and it


kind of, you know, brings up a question


that you have, um, of course, just


always throw it in circle, tag me, and,


you know, I'll be to kind of answer it


and can maybe even like show an example


if um if I need to to kind of help out.


So um all right guys, well you all have


a good rest of your day and I will see


you guys tonight at 7 on the live


scalping call if you want to join me.


Okay, bye.$video_16_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_16_summary$You'll learn the difference between inside and outside liquidity and why that matters for entries and stops. Shea explains where price often goes next and how to avoid placing stops in obvious danger zones.$video_16_summary$
      ELSE summary
    END
WHERE sort_order = 16
  AND title = $title_16$Liquidity & Stop Placement$title_16$;

-- Backfill watch-page content for lesson 17: Payout & Capital Protection
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_17_transcript$Okay, hold on just a second. I was going


to check this chat. What time is the


call you do on Mondays before this one?


So, the one before this, the live


scalping is at uh 7:30 a.m. Central. And


if you go into the events calendar uh


section and circle, it will have like a


link in there that you and I pretty sure


all the like links to join are all the


same. So you can either click on that


one or just click on any of them and it


should bring you to that same Zoom call.


Hold on just a second. Sorry.


Okay. All right. So, on this call, um,


I've just kind of noticed, of course,


I've struggled with it. I know probably


a lot of people struggle with it. And it


really doesn't matter if you're in a


prop firm, a live account, um you know,


whichever account you're working with.


But um but I know whether we are not


getting payouts or you know I know like


for me personally like I passed so many


challenges especially in the beginning


and it was like I would pass them and


then I wouldn't get the payout and you


know then I'd end up just losing the


account. I know for me, I would I was


wanting to hit like the jackpot. Um, so


I didn't want to take little payouts. I


wanted to not take a payout until I was


at like a ridiculous number. Like


probably what I normally made in a year


at any other job. That's what I wanted


to hold out for for my one payout, which


is crazy thinking now. Um because I'm


like I mean I've been in this prop, you


know, account and I passed it and I've


been working on it for a week. Like I


want a $10,000 $20,000 payout and it's


just not realistic. So, I know a lot of


us, you know, the whole point of us, you


know, getting prop firms, passing prop


firms, of course, or if you have a live


account, it's to grow it and to get the


payout. That's kind of the ultimate


goal.


But I know, you know, some of y'all may


kind of have the thinking like I did,


and you kind of want to hold out for


that bigger payout. And in the process,


uh, it's almost like the emotions come


into play and, you know, you lose an


account. I know I probably did a lot of


revenge trading. Uh, you know, it's


like, well crap, I lost this one. Now I


need to make double it back. And I was


just I was going backwards. And so I


wanted to kind of just give y'all some


pointers. Let me share my screen


of things that helped me.


And I feel like it could help y'all. But


I also want to kind of challenge y'all


to hopefully do these and get over that


hump of starting to get payouts because


I really feel like our brains need that


reward.


you know, to kind of make it seem worth


it. Um, and of course, you know, all the


wins without a reward is is just another


job. And I know most of us are doing


this to get away from a regular job. you


know, a regular 9-to-five job, you know,


you work at for the, you know, 30 years


or however long a, you know, don't get


to spend time with your babies, your


spouse, your family, don't get to go on


vacations. I know we're all kind of


doing this to get away from that. And so


obviously we know that in order to


replace that we're going to have to get


payouts or make enough on a live account


to replace that income. Um and I know a


lot of us to try to put it into


perspective even though I know we all


logically think it but I also know we


tend to forget it. I know I I probably


still do honestly, but it's like in a


regular job,


we're okay making, you know, whatever


you're getting paid an hour, whether


it's 100, $200, $300 a day, and you're


okay doing that, you know, working 8


hours a day, weekends off, whatever your


schedule is. But it's like we're content


doing that. But for some reason with


trading, and I know we've seen bigger


wins, so that may kind of distort it a


little bit for us, but we will see a


little win like that, $2, $300 a day,


and it's not good enough. you know, we


have to keep going and keep pushing and


um you know, and I know that we want to


build a cushion


uh for the accounts like take profit


trader, they require you to build a


cushion before you can have a


withdrawal. Um and then of course on um


Topstep, you know, we kind of just build


our own draw down. And so


outside of that, um, you know, I want us


to kind of try to rewire our brains of


breaking through a block that I think


probably a lot of us have. And I kind of


think prop firms probably create a lot


of that block for us. So there are pros


and cons of course with the prop firms,


but I do feel like a really big con for


that is it almost takes logic out of the


equation and we see those really big


wins. So, whenever we, you know, you may


get a $5,000 win one day and then the


next day whenever, you know, you only


make a $500 win, it's like, well, that


day sucked, you know, but it's like, but


in your regular job, you will go, you


know, work 8 hours and, you know, for


the same amount of money or less. And


it's like, we're okay with that. So I


want us to just kind of bring it all


into perspective and


so I was trying to think of like things


that are common mental blocks that we


may have and um of course number one I


think is fear of losing it all. So, you


know, if you're kind of thinking, well,


if I withdraw, then I might lose the


account, you know, if I don't have


enough cushion, so I really need to let


it grow to, you know, a really large


amount and then I will withdraw. But,


you know, in that process, I think a lot


of us go backwards or we lose the


account, we have to reset, you know, so


we're just continuously starting over


and we're never actually getting to that


payout. um you know so


um you know if you're afraid to you know


basically have that success


uh then you unintentionally sabotage


rather than you know kind of facing what


that next level is which even though


it's all you know positive things but we


have that block so it's almost like


subconsciously we stop ourselves from


getting to that next level which for a


lot of us is being truly considered a


traitor. Um which kind of you know goes


to the next one impostor syndrome. You


know well that win was a fluke. Um, I


need to prove it to myself, you know,


more times uh before I truly believe


that like, you know, your skill of


identifying the trade and executing the


trade that that actually is what you


know caused the success. It wasn't just


a fluke of you getting lucky. It was you


doing the work and learning the skill


and actually executing it. Um and of


course this shows up uh and not


celebrating. So uh you know not


documenting it whether it's journaling,


telling somebody and of course not


withdrawing. So you're not seeing you're


not celebrating it in any way. You're


just you know going again and going


again and going again. uh but you're not


actually celebrating what that win just


did. Um and you know, so of course you


don't believe it. You don't believe


you've earned it even though your


results say otherwise. Um


and of course I think this was probably


my biggest one was the all or nothing


mindset. Um almost like my balls to the


wall thinking. uh which I'm not going to


lie and say that I don't still have


that, but uh but I at least try to


balance it out. Um so, you know, a lot


of us may think if it's not at least a


$1,000 payout, what's the point? You


know, I need to at least get $1,000


payout


and or grow my account by $1,000 and


then I will take the payout. Um, but of


course by doing so you're undervaluing


the small wins and that kills momentum


cuz we all know even those small wins


can compound uh to something larger. Um,


you know, so you don't need $1,000 to


change your thought process. You just


need proof. So you need to prove to


yourself, to your brain that you know


you are having success.


Um, and a lot of these, um, you know,


kind of questions like if you want to


try to figure out maybe where your block


is if you aren't really sure what's


causing your block. Um, you know, you


can ask yourself these questions. So,


did you pass the challenge? Are you


funded? Um, that's not supposed to say


life. That's supposed to say live.


um you know, or do you have a live


account? Have you told someone you're


planning to withdraw? Um and do you know


your broker's withdrawal policy, whether


it's with a prop firm or even a live


account? Uh you know, if it's back to


crypto, back to a checking account. Just


really understand what that process is


ahead of time. Um and of course, have


you journaled your first five live


trades? So either with a funded account


or in a life account that you know is


your own. Um and so if you kind of


paused on any of these then that may be


an indicator of where your block is. Um


I know a lot of us have already talked


about this one right here. Have you told


someone you're planning to withdraw? I


know a lot of us are kind of on the


fence on that. We either think um I'm


going to jinx it if I say, you know,


where I'm at that I passed it, that I'm


heading for a withdrawal.


um even outside of um you know our


circle group maybe even uh like our


family, our spouse's support system


depending on


if you have that and I know a lot of us


we can have really supportive partners


or family but there until they I guess


really understand trading ing, there's


just going to be, you know, they're


going to be a little leerary of it. And


I know I was before I started trading.


So, I understand other people kind of


having those feelings as well. So, I


know for some that kind of stops us from


saying anything.


Me personally, there was very few people


that even knew I was trading until I got


a payout. And I think I just almost


wanted to be ahead of it, I guess. So if


I did get, you know, any negativity


kind of thrown my way whenever I told


somebody what I was doing, I wanted like


that proof of, you know, being able to


show them, well, look, you know, I've


gotten a payout. So, you know, nah.


Like, I don't know why I did that, but I


just felt like I needed to have that


proof


cuz I was anticipating


negativity with all of this. Um, you


know, so that may be kind of a block.


So, you know, you can either just not


tell anybody until you get a payout.


They don't even know how big of a payout


it is. you're going to say, "Hey, I made


some money." So, um, okay. Um, why the


small payouts can change everything. Um,


and it is really just symbolic even


though yes, it is money that's in your


account that was not in your account


yesterday, but in the, you know, full


picture of it, it's just symbolic. It


breaks the loop of consumption,


education and waiting. So we all know


how much work we put into this. We


consume a lot of information and you


know of course with us consuming a lot


of that information, you're learning a


lot of different education. uh whether


it's you know just learning even if it's


only one strategy but you've never


looked at a chart before that's a lot of


information that you're kind of


consuming just to get to the point of


being able to set a trade and and it's a


lot um of information. It's a lot of


hard work. um you know you kind of


dedicate a lot of time and then even


once you get to the point if you're in


say a prop firm and you pass it you


still are in that waiting period of well


now I need to grow it and you know so


from beginning to end is a lot of time


and um you know so it says I'm a trader


I got paid for knowing how to read a


chart for staying consistent


for staying accountable for following my


rules and for putting in the work. So


just taking any kind of payout


tells you all of this stuff right here.


And I know for some it's kind of hard to


say that. You know, it kind of goes back


to that impostor syndrome. It's like,


well, I mean, but I'm not really a


trader because, you know, I'm not like


some of these people I see on YouTube


and, you know, I'm not out buying


Ferraris and and all that stuff. Um, but


you


learned a skill, you executed this


skill, and you profited. So, whatever


you profited, even if it was5 or $10,


it's5 or $10 that you did not have


yesterday. So you there is a reward for


all of the hard work that you've done


and you know it's kind of like starting


out working after high school. You're


not going to get a CEO job fresh out the


gates. So you got to kind of work your


way up. So even if you start with very


small withdrawals and work your way up


just like you would in any other job,


you know, just try to keep it all in


perspective to not think that you're


going to learn this skill and next week


you're going to be able to go buy a


mansion, retire you and your family, you


know, buy whatever you want. like it's


just it doesn't work like that with


anything else in the world with any


other job. Um not usually anyways.


So just know that even though you may


only be taking out a very small


withdrawal


that will grow. It will grow with you


know um with thing different things that


you learn with your skill level. the


more you do it, the more you reward


yourself,


those payouts will increase over time as


well. Um, and so some suggestions for


getting unstuck,


set a micro goal. So, withdraw $10 and


use it on purpose. So, actually withdraw


it out of your account and go buy


something for you that you want. And of


course, you know, if it's just5 or $10,


it's going to be something small


probably, you know, like coffee. I know


I've mentioned like a pop flowers,


you know, a new journal to journal your


trades, whatever it is for this small


amount, just, you know, go ahead and


um go purchase it. I kind of like you


know Melanie was talking with her um


having her kids color in that um her


little reward system. I think that's


great. And you know with her having kind


of already in the back of her mind if I


get you know if I do this and I get this


colored in I am going to buy this. So,


you know, even make a list, you know,


$10 unless I'm going to buy this, you


know, next week I'm going to increase it


to $15 or $20. Have a list of things


that you want for that dollar amount.


And you know, so even if you need to


write it all down and already know what


you are planning on getting whenever you


get that payout, that will just help


almost keep you accountable for


following those rules. And um and we


know that, you know, you can withdraw


$10 even if it's in your live account


and you're following the butterfly


tracker. you know, make $10 on a trade,


withdraw five of it, you know, withdraw


half of it. And you don't have to do it


obviously every day. So, you're gonna


keep compounding it, but you know, once


a week, withdraw $10 and, you know, go


buy yourself something. So, you're still


leaving a majority of it in there to


compound, but you need to reward that


part of your brain that makes you


realize that it's worth it. All the hard


work that you're doing is worth it. And


and I feel like that's where a lot of us


kind of get in this uh we get stuck. Um


and of course, reward in real time. Have


a payout purchase ritual. you can name


the ritual. Uh so maybe every Friday,


you know, you make a withdrawal. Um and


like I said, it can just be $10. More


than likely, you're going to profit $10


at least in a week's time frame. Um


and of course, you can tie it to the


butterfly effect tracker. uh one small


payout leads to confidence which leads


to consistency which then leads to your


legacy that we are all doing this for.


We all have that end goal, whatever it


may be, whether it's retire from your


job, to help family out, you know, to


donate, whatever you your kind of end


goal is.


That's what all of you know, one small


payout leads to that end goal. Um, you


know, it just may take a little bit of


time and that's fine. Uh, I can almost


guarantee you though it will not take 30


years like it would for a regular


nine-to-five job that you would probably


stay at until you retired. I can almost


guarantee you that trading, if you stay


consistent and reward yourself, that it


will not take 30 years before you hit


one of your goals. Um, so just remember


that a lot of us are are just fine and


dandy doing that for 30 years. Uh, you


know, we retire, our kids are grown, you


know, maybe depend on what you've done,


you've missed out on


sports, uh, you know, dance recital,


whatever it may be. Um, you know, I


always think of like my husband with


whenever he was in the oil field, how


much he missed out on because he was


just he was literally out of town for


like 8 months out of the year. And you


know, but it was just what what you do.


Um, I know for like my generation, it


was definitely embedded in us. You go to


school, you graduate, you work,


period. That's it. That's all you do.


And so it is really like embedded in us


that like we've got to go to work.


That's all we do. And um you know so we


know that trading we do see the


potential because we do have those days


where we are able to profit quite a bit


and you see on those days the potential


like wow I just did that. I don't even


need to do that every day. You know, if


I did that once a month, that is so much


more than what you're probably making at


your regular job. And you may have done


it in 3 hours in a day, not you know, 8


to 10 hours or whatever you're working.


And you know, so we do see that


potential. I know a lot of us just that


greed creeps in and if we've done it


once, we want to do it every single


time. I know I am 100% guilty of that.


Um but I think if you try this it can


help kind of uh snap you out of that a


little bit. Um you know and then also um


another suggestion is voice or journal


that fear. uh you know if I withdraw


withdraw out of my account and then I


lose a trade I am afraid that blank you


know that I'm going to lose my prop firm


account or whatever it may be you know


if I tell somebody if I tell my spouse


that you know I've profited $200 I'm


getting ready to make a withdrawal I'm


afraid that


I'm going to get met with negativity


like well goll Holy, you've been doing


this for 2 years. You're only


withdrawing $200. I mean, I can hear it.


I'm sure I have heard everybody say what


they have heard at some point. Um, and I


get it and it, you know, but challenge


it. You know, if that is kind of what


your main fear is and you're afraid that


you're going to be met with that kind of


response, then challenge it with, you


know, already have a reply back.


You know, if for instance, that example


I just gave is what you're afraid of,


then, you know, just come back. Hey, you


know, did we have $200 yesterday? No, we


have $200 more. and like shut the f up.


I'm divorcing you. That's all you got to


say. No, I'm just kidding.


But um but yeah, so a lot of times I


think if you


already kind of have in your head how


you want to challenge whatever your fear


may be, then you can kind of work


through that and it won't be necessarily


the unknown.


And if y'all's brain is like me, I will


always make up worst case scenario until


I am like proven otherwise. So a lot of


times it is just the fear within us and


not reality,


you know. So if you're really kind of


fearful of that and they come back with,


"Wow, babe, good job." You know, it's


like, "Well, I've just been


worrying about that for way too long for


nothing." Um, so, um, all right, let me


see what else.


So, I think this was just kind of like


the um, like a ritual thing if you want


to do um, you know, but repeat every


time you withdraw again. Even if it's5


or $10, you know, name the win, whatever


you want to name it. This profit,


whatever it is, came from me trusting my


strategy and managing my risk, following


my rules. Whatever it is, uh that you


know got you those profits, write it


down. Um you know, you can even journal


what you did well on the trade. And it


can be any trade, even if you want to


put it on the actual chart. um you know


with each trade take a picture of it you


know it um like on our chart where you


can go and download the image maybe do


that you know if you want to clear it


off your screen but you know just you


can document it somewhere um withdraw


with intention choose a small amount to


withdraw ahead of time small at first


grow as you go don't wait for a big


number you're training identity


not chasing size So, you want to train


that identity muscle of I am a trader.


Um, buy the reward. Pick something


physical to buy. Coffee, candle, new


pen, lip gloss, dollar scratch off


ticket. I don't care what it is. Just


buy something physical that you can hold


in your hand.


Cuz you're not just buying the thing.


You're buying proof that this works. Um,


capture the moment. Take a picture of


you holding what you bought and say,


"This was paid for by my chart skills.


Nobody else's." You execute the trade


because you see something and you're


following through with it. Um,


lost my


post. So, I'm going to also put a space


in circle. Um, you don't have to upload


it in there if you don't want to. Uh,


but I would I would still suggest you


taking a picture of you holding what you


bought and even if you have to just keep


it to yourself in a private album if you


don't want anybody else to see it. Um,


you know, but title it proof I am a


trader to document your growth. You


know, to see with my first withdrawal, I


bought an ink pen. With my hundth


withdrawal, I, you know, put a down


payment on a car, but just to document


your growth from your very first payout


and what you bought from it to but you


will see the proof of your growth and


you know, you will go back and look at


it and maybe not realize how much you


have grown as a trader. But whenever you


can go back and look at that, you'll


realize how much you have actually


grown. Um, and repeat it again and


again. Make it a regular practice. So


whether you want to, you know, make a


plan to withdraw weekly, bi-weekly,


monthly, whatever you want to choose to


do, but do it consistently. So, you


know, if you decide weekly I'm going to


withdraw $10, then every single week


withdraw $10. And, you know, maybe after


a month of doing that, you can kind of


re-evaluate,


you know, see what your growth has been


and, you know, maybe you increase it the


next month to $20 or whatever. or if


you're kind of wanting to keep most of


it in there uh to compound, then you


know just keep it a very small dollar


amount. Um and and add it to your


trading checklist. Um so you know like I


know some of us already put like the


rules on the chart you know of what


confluences you're waiting on you know


or whatever. um add that to it. You


know, did I pay myself this week and


that way you can um have that as a check


off from now on? And I think that's it.


Yep, that was it. So, um so those are


kind of the things that I want to


challenge you guys with. Um, so I think


for this month,


not necessarily a it's kind of like a


challenge, but a challenge to break the


pattern. So, you know, make a


withdrawal.


Tag me if you post it in circle or you


don't have to tag me. You don't have to


post it if you don't want to. U, but I


will have a space in circle. um you know


to where if you want to post what you


have bought with a payout and for one


you can see your growth but also if


there's anybody maybe in the beginning


of their journey if maybe they're at


part of their journey where they're


feeling a little discouraged they can go


into that space and they can look and


see you know what they bought something


with you know their skills


And


it wasn't a Lamborghini,


it was a journal, you know, it was a cup


of coffee. And and that will probably


encourage so many people uh because I


feel like a lot of us um you know, we


don't really see much of what anybody is


doing with payouts. And it maybe because


for one they just don't think to take a


picture of anything. Uh or they're just


not taking payouts. They are trying to


compound so much that they're never


rewarding theirelves. So I'm going to


put add that space into circle. Um so if


you want to do that of course I will do


it as well. Um,


yeah, exactly. Well, they have got


little Hot Wheel Hot Wheel Lamborghinis.


We'll uh we'll post that on the ones


that do those uh YouTube channels where


it's like, "Buy my $800 course and in


one week you can buy a Lamborghini


also."


So, um but yeah. So, yeah, I will have


that in circle. uh you can post it. Um


and we can just kind of encourage people


who maybe they're starting out and but


almost to bring it back to reality that


you know you're not going to make your


first, second, 10th withdrawal from your


account and be set for life. You know,


you're going to start out small. But if


they see, you know what? Wow. They did


not have this the money to go buy the


ink pen, but their trade allowed them to


make the profits to go buy that ink pen.


So, you know what? I'm going to do the


same thing. And they'll see that you can


still go buy things with the little


withdrawals that you do. So, um, so


yeah, I just want to kind of challenge


and see if,


you know, for the month of February, I


really think it could change just the


the cycle of


just this loop that I know a lot of us


are in right now. Uh, once you get in


it, it's hard to get out of it. And I


think that can be the beginning of kind


of creating that new muscle memory of


slowly withdrawing. Um, all right. I'm


going to look at the chat real quick.


Yes, exactly. Love the idea of


withdrawing a bit each week. each week


to encourage yourself that you're


staying consistent and rewarding your


hard work. Yes, my husband is so that


person's supportive, but but where's the


money? Yeah, I I get that. I can see


that.


And my problem right now is this


challenge took me so long to pass and


now that I am funded, I have a lot of


fear of losing it. So, I'm being overly


cautious with my risk. So each take


profit is so small my cushion feels a


million times away. Million miles away.


I'm going to start gener journaling the


I can't talk. Start journaling my


trades. I never do that. Yeah, I


definitely tried to do that and I I


understand. I think I am the same way.


Um especially with you know I know Topep


doesn't require you to have that


cushion. I've just kind of always uh


created one I guess myself, but it was


probably based off of take profit


because you have to uh have whatever the


draw down is that is your cushion. So


you have to grow it uh that amount


for it to stay in there. And then


anything over that you can withdraw


daily if you want to. Um, and then of


course if for some reason you ever lose


the account, that cushion amount that


you grew and kept in there, you even get


a portion of that back, which I love


about them. Um, so but I'm the same way.


As soon as I pass and I just have in my


head that dollar amount that I have to


get that cushion to, um, I know that I


probably move my stop loss up. like I


will be a dollar in profit and I'm like


I'm trying to like break even, you know,


cuz I'm like so fearful of that loss.


And so I'm the same way. So I think once


I do pass those challenges, I probably


get even pickier with the trades that I


take. Um and then if I ever want to get


maybe a little bit riskier to get that


out of my system, I do it like on


another account. But yeah, I get that.


So try try the journaling like you had


mentioned and


see if that helps you because maybe just


having it on paper


seeing that you followed your rules that


all of your confluences are there that


might help kind of you know ease your


anxiety a little bit of you know what


this should go my way because all of the


confluences were there and and then if


all else fails. Close the chart and


don't even look at it.


Um, got to get my funded accounts out of


draw down first.


Yeah, I definitely understand that too.


Yeah, and it it is a struggle. I know a


lot of times and I know a lot of us have


already kind of mentioned this in circle


that once you get almost so far in draw


down it's just like you know what I'm


just going to go all in and if I lose it


I'm better off just resetting it and I


feel like that's where we get stuck in


that loop. So even if you have like a


small live account and you're able to


maybe get give yourself a little bit of


reward from that um you know then maybe


use that in the meantime


you know or maybe even have one of your


rules if you do have a live account that


I cannot reset or buy another prop firm


until I profit that amount. account in


my live account. And you know, it that


kind of may be another rule of where you


just don't feel like you're throwing


money away at prop firms and you're


never getting rewarded. Um, so you know,


maybe just use the live account.


Uh, yeah, small live account is in


profit. Just struggling with my funded.


Yeah. And I think a lot of that is from


our emotions. For one, the prop firm is


probably a larger dollar amount. So even


though in a good way, the pro the take


profits a lot more, but you're seeing


that stop loss where you probably need


it to be and all you think about is that


stop-loss amount to where it almost


overshadows


what the takerit amount is. if you hit


it cuz all you're thinking about is oh


my god if that hits that stop loss that


is a large dollar amount and I feel like


with our like small live accounts a lot


of those are you know $20 or less until


it grows you know quite a bit but so


it's a lot easier for us to see a you


know $10 stop loss and be like nah oh I


I'm fine running to Walmart I don't need


to watch that I don't need a babysit


that and you know where the larger


amount if you see a $1,000 stop loss or


whatever it's like you feel like you


need to babysit that. So, um, so yeah,


try journaling if you see that it should


go your direction and if not, then it's


just the market being a market. But, um,


but if you see that you followed all


your rules and your confluences, then


yeah, maybe just close the chart and


don't even look at it, you know. Or


maybe if you do alerts, set your alert


between like your entry and your take


profit, kind of like I do, like kind of


right in the middle. And then that way


if an alert goes off and you know that


you're about halfway to your takerit,


then you can kind of decide from there


if you want to maybe move it up to break


even.


Uh yeah, I know changing the chart to


reflect ticks instead of dollar amount


can also help a lot with that, you know,


just that emotional uh the emotions of


seeing that dollar amount where if you


just see that, you know, your stop loss


is,


I don't know, 50 ticks away or whatever,


then


you're just like, whatever that is,


whatever that dollar amount is because I


know I probably wouldn't go through the


trouble of trying to figure out that


you know that math but and I guess you


could maybe do that just to make sure


the dollar amount is still good but um


but yeah for the most part I think


changing it to tick is a great idea.


Um,


and also make sure that you are in


micro. Uh, that was another thing that


was hard for me. If I got in draw down,


switching over to micros and slowly


building it up. I wanted to be in the


minis and I wanted to make it all back


in one trade. And I know that probably


caused a lot of um anxiety, but but


yeah, once you do get in draw down, uh


switch to the micros. Uh cuz even with


like take profit, whenever I'm trying to


build up to that cushion, I switch over


to micros at least to give myself a


little bit of cushion because of course


with them you have that um intraday draw


down, which sucks. Um and so you do kind


of want to use maybe the micros to build


that cushion up just a little bit. let


it reset the next day and you know kind


of just slowly do that. And then once


you have the cushion if you want to


switch over then you can or if once a


trade is going in your direction maybe


add another micro or two to that. Um


yeah two micros is a lot. I agree. And


if some of them, even one micro, I'll


like go just that one micro and I'm


like, I don't even know if I want to do


that one. Let me let me switch back over


to a 4x pair or something. Um, all right


guys. Well, do y'all have any questions


about any of this block stuff? And if


not, um,


like I said, I'll go ahead and add that


space to circle. And that way if we want


to um you know start kind of posting


some things on there then then we can do


that. Um I did request a payout on


Friday. Uh but


uh yes I will Michelle I will post that


word document in circle as well. Um, but


um, a suggestion I have for you guys, if


you're like me, never look at my


driver's license. Uh, so I'm getting


ready to go to the DMV to uh, get a new


license because I can't get a payout cuz


my license has expired. Uh, actually


just expired on the 31st, but still. So,


um, part of do you know your broker's


withdrawal policies and all that? Also,


make sure that you have your


together and your license is up to date.


So, um, all right, guys. Well, I'll go


ahead and


>> Yeah.


>> Were you going to give a reward today?


>> Oh, shoot. Yes. God, see, I already


forgot again. I text Jill at the


beginning and I was like, "Ah, I forgot


that I was going to do that today and I


already forgot it again." Yeah. So, I


don't know if any of y'all I think maybe


I just posted it in circle about um you


know, we have the regular reward system


for the butterfly pass uh to where you


know, you kind of can get points as you


go if you didn't want to just pay that


upfront cost uh you know to get in


immediately. Um but um I do want to I


think I'll probably do it like monthly.


Um, I want to reward somebody that I


feel like even though it probably


wouldn't take them very long to get the


point system anyways. Uh, but I've


noticed that even before I started kind


of implementing that point system, uh,


they, you know, just always posted. And


I think one thing that I'm probably most


proud of that they would post is uh when


things were not going very well, you


know. So they were really good at


posting like learning moments and


almost putting a lot of it out there


that


a lot of us don't want to put out there


because it's not fun stuff. Um but so I


want to reward this person. Um, so the


butterfly pass is like a monthly basis


thing. So for the next month, I wanted


to just go ahead and throw her in there.


Uh, and so I was glad that to see that


she was on the call today. Uh, but


Melanie,


I want I want to go ahead and put you in


the butterfly pass. Um, I feel like


you're you're really good at, you know,


if you're struggling with something. I


know that even though you may DM me


separately, you will also go into circle


and I know that whenever you do that, it


it probably makes I don't know how it


could make everybody feel better. Uh


because I know that everybody


feels the same things that you're


feeling, struggles with probably


everything that you feel like you


struggle with. And so I do feel like


it's really good uh you know to just


reality to just be real and you know


where somebody's struggling but maybe


they feel like well nobody else has


really posted about this so I kind of


feel stupid if I post about it and but I


I can tell just whenever you post that


just with the comments that come in that


it probably helps a lot of people. So,


um, so yeah, I'm going to go ahead and


put you into that butterfly pass. I will


do that as soon as I get off the call so


I don't forget again.


But but yeah, I just I definitely want


all of y'all to continue to do that


good, bad, ugly post, whatever in


circle. Don't ever feel stupid for doing


that because I guarantee everybody


is going through it the same time as you


or they for sure have felt what you are


feeling at some point including myself.


I still do you know a lot. Um, I've


learned that if I'm stressing over


something, I best just stay away from


the charts because I me the charts and


stress don't jive very well together.


Um, so yeah, I think what you're


learning to do and I think what I had


kind of uh messaged you privately, but


um whenever you get to that point of


making your withdrawals, you will have


already done so much mindset work.


That's the struggle. You know, the skill


I think is the easy part is the mindset


work that is hard. So by the time you


get to that point, you're doing all the


hard crappy work first. So yeah, once


you get to your payout phase, you're


going to be golden with your mind


mindset work. So um so yeah, I just I


appreciate you for posting and I


definitely want to, you know, reward you


for for doing so. But all right, guys.


Well, I'm going to go ahead and hop off


here and I will see you all on tonight's


live. Um, in the meantime, I will um get


that word document uploaded and that


separate space, you know, so if you want


to upload anything. All right, guys.


Have a great day and I will see you


tonight. All$video_17_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_17_summary$This lesson focuses on protecting both payouts and trading capital. Shea explains how payout rules and capital preservation should influence the way you manage trades and expectations.$video_17_summary$
      ELSE summary
    END
WHERE sort_order = 17
  AND title = $title_17$Payout & Capital Protection$title_17$;

-- Backfill watch-page content for lesson 18: Trading Continuation & Trend
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_18_transcript$All


right. So, I know I've seen um a lot of


questions and especially with the way


that NAS and gold probably a lot of


other pairs, but I know those two in


particular have kind of just been like


once they get going and take off, they


just like go. And um you know, I know if


you feel like you maybe don't get in


right at maybe like a support or


resistance area,


you know, you kind of feel like you've


missed out on like the whole move. But


um but I want y'all to kind of get


comfortable with,


you know, getting in maybe in the middle


of the trend. Uh but not get trapped to


where, you know, you feel like you're


catching the knives or as soon as you


get in, that's when it starts pulling


back. Um so I just kind of just get


familiar with pullbacks and get


comfortable with them. So, I don't want


you to necessarily panic whenever you


see a pullback. Um, you know, if you


feel like you kind of mi missed that


first initial takeoff,


uh, that's when I want you to maybe


implement alerts. Of course, if you have


like a Trading View account, uh, set


your alerts, be patient, wait for a


pullback, and then kind of use that as


your entry. Um, don't force a trade, and


of course, don't chase a trade. Um, you


know, if it's just shooting up or down,


like, don't try to jump in on a huge


green or red candle. Um,


you know, I want to gonna kind of just


show you some different things you can


look for. Um, so


of course


once you see that impulse impulse and


that initial takeoff, that's where you


want to wait for a pullback and then a


continuation


confirmation to know when to get in. So,


um, of course, the first one, kind of


the main one that I think a lot of us


already know is the using the EMAs, the


921 EMA. Um, you can kind of treat it as


a support and resistance. So, you know,


you'll notice price will kind of retest


the EMAs


before they go back up. Like, they'll


kind of pull back into it. um you know,


so price retesting the EMAs in a trend


equal an opportunity to get in. Uh it's


also sometimes what I use if I'm going


to stack on a trade. Um I'll kind of use


those pullbacks. So um when price pulls


back into the nine, of course, when it


pulls back into the 21, it's even


better. And I'll show you examples of


all these. um and then confirms


continuation


with like the confluences. So the higher


high, the higher lows in an uptrend, uh


fractals, break of structure, all of


those. Um if it retests the 21, you can


sometimes use the 9 EMA. So I'm going to


kind of be bouncing around. I try to


find examples near this


Okay. So, and I I'm on the 15 minute,


but


um Okay. So, you can kind of see


whenever


gold, you know, so if you felt like you


missed out whenever, say it retested


right here at this, which was probably a


support or resistance at the time. a W


break of structure EMA cross. So if you


feel like I missed this opportunity,


when can I get in now because you know


other than of course this, you know, if


you just see it just is going and going


and going and going and you maybe don't


want to wait until it gets to say the


next support or resistance. You want to


get in in the middle of the trend. So


you can see right here whenever price


went up we came back and retested and


then you know so you can either whenever


you see that wait


for a higher fractal uh like on the one


minute you would probably see it a lot


quicker than this one right here. Uh but


you know once you see that pullback and


then we come back and we cross back over


that 9 EMA then that's where I would


feel comfortable getting in. So of


course if I was trading the 15minute


when I saw this pullback and we crossed


over and closed above this 9 EMA then


you know I would probably put like a


pending above this fractal. So, you


know, get triggered in based on the


EMAs. Um, so just, you know, it'll work,


of course, with any time frame. So,


whichever time frame you're kind of


trading with, just you can go off the


confluences from that time frame. Um,


okay, let me go back up. So, I'll kind


of just go through each one of these and


then if y'all have any questions, let me


know at the end. then I can go back over


them.


Okay. Uh the second one is uh you can


wait for it to pull back into a a fair


value gap. Uh so you know you see price


pull back into a fair value gap then you


know goes like in a bullish trend. So


say if we pull back into a fair value


gap and then we start coming back up and


you see the break of structure


confirmation


um you know going in the intended


direction uh then you you know just want


to kind of remember that you can enter


in where the imbalance


is kind of inviting buyers or sellers to


get back into the trend. um you know so


it's not the initial breakout but you


can consider this as like the reload


zone.


So let me hop down here kind of show you


what I'm talking about.


So right here we had a fair value gap.


Of course you can see the trends just


going going. Whenever you see price pull


back into that fair value gap, then


we get a higher low. So, we're still


confirming that we are still in a


bullish trend. So, if you see the higher


fractal, if you wanted to wait, you


know, for that break of structure


confirmation, then, you know, you could


set your pending at the fractal. Um, so


you can use fair value gaps to wait for


price to pull back into those. Um,


sometimes that may not happen for a


while.


You know, I mean price may come,


you know, pretty far away before it


finally pulls back into a fair value


gap. But, you know, you can mark them


off on


15minute


uh 5 minute. I've marked off 5 minute


FVGs before


since I execute on the one minute.


Um, let me


Okay, Tammy, are you talking about with


the like this one if I was getting in on


the fair value gap where to put the stop


loss?


Okay, I let me move this out of the way.


So, if I was say getting in, wanting to


wait for a break of structure,


I'm just going to throw my take profit


anywhere up there. I would want to be


below


the fair value gap. uh preferably


even the like low before the FEG. Um you


know, so I think that that's where I


would feel comfortable. I wouldn't want


it anywhere inside there cuz, you know,


I feel like


the orders can get filled anywhere in


here. So, I would want to be definitely


outside of the fair value gap. Um,


possibly even the low before that. And


of course, if you know, I don't know


what time frame you're trading on, but


like the one minute, you know, it may be


a little bit closer like the low um to


where it may not be this far down, but


that's where I would feel safe putting


that.


Okay. Now,


okay. You can also use a a support and


resistance flip. So, I know some of you


keep up um I don't remember who it was,


but somebody had said that if they have


like a you know old support or


resistance area, they kind of mark that


line. Keep it on their chart, you know,


and maybe just do like a light pink or


just some other color to where you know


it was a previous say support or


resistance. Okay. So you know of course


when price breaks say the resistance and


retests it that then and keeps going up


that resistance of course then becomes


your support. So you can enter when


price proves continuation with the


confluences higher highs higher lows


break structure


use the market's memory. So broken


levels often attract retest.


If that level now rejects price, it


confirms continuation. So


of course I know a lot of these lines


are off, but we will kind of just


pretend like they are support and


resistance lines. So this one right


here,


say if this was a resistance, you know,


price comes up, breaks above it, but


then comes back and retests it and then


we start seeing confirmation that we are


in a bullish trend. So


you see the


higher lows


and then of course break of structure.


So where this was say a 4hour


resistance area but whenever price broke


above it and then we had a retest and


then we continued up.


Y'all know that that resistance is now


your support uh or it will become your


support. So you know this is probably


like the next day or that evening


whenever you go to mark up your charts


again this resistance may now be a you


know support level and then your


resistance you know it's going to be


somewhere up here now. So you can use


that support and resistance flip. So,


you know, price breaks above the 4hour


resistance, comes back, tests that 4hour


resistance,


doesn't go below it. We continue up with


our confirmations.


So, of course, this is another one of


those where you may not have necessarily


the EMA cross. You may not get that big


of a pullback, but I would still, you


know, use the other ones. So, you know,


I would wait for a higher high or a


higher low and a break of structure. Um,


and sometimes on the lower time frames,


you might even get like your W or your


M, but but you might not get the EMA


cross necessarily,


but you know, use it resistance turning


into a support. You can use that as


pullback for confirmation to get in


and then a liquidity grab before


continuation. So I say in an uptrend


price pulls back slightly and suddenly


dips below a swing low grabbing


liquidity but then immediately reclaims


that level with a strong say bullish


trend or a change of character. I enter


in on that reclaim candle close. Um, and


of course, market uses these traps to


grab stop losses below a swing, loads up


on orders, and then resumes the original


trend. Um, let me see if I


was going to take that.


Let me go back.


So, I think this one you could see it


better on


that lower time frame.


There it is.


Okay. So, you can kind of see


if this was still your resistance area.


price comes down,


wicks below


and then


has that big continuation candle. So


whenever you see that especially these


you know kind of strong rejection wicks


then you know kind of wait and wait you


know get your other confluences. So, you


know, of course, this if we would have


gotten a lower low or a lower high, you


know, something like that to let us know


that it's not a liquidity grab. It is a,


you know, continuation of possibly going


down. But whenever you see these strong


rejection wicks,


kind of just get used to um visually


seeing that and like thinking in the


back of your head that that might be a


liquidity grab and don't jump in on, you


know, that strong candle going down


thinking that you're going to miss out


on the trend because a lot of times, you


know, especially buy a support and a


resistance level, you'll get these


liquidity graphs. So, you know, a strong


rejection wick and then an immediate


uptrend uh candle. So, whenever you see


that,


just wait for your other confluences.


So, of course, once you see this higher


low and then, you know, depending on


your EMAs


on if you get a cross or not,


of course, this one you get a EMA cross,


you know, you can start seeing the W if


you want to wait for a break of


structure. Um, that's a liquidity grab.


So whenever you see that, that can be


your sign, you know, to get in. Um cuz


you know that we're grabbing liquidity.


Keep losing this place. Uh grabbing


liquidity and then all they are doing is


loading up on these orders and they're


going to push price right back where


they want it. So you can take advantage


of that and get in on, you know, those


orders as well. Um, so that's where, you


know, patience, maybe setting alerts.


Um, you know, really make sure if it's


near a support or resistance level that


you're waiting until you get all of your


confluences with whatever time frame


you're on before you jump in because


those are of course high levels of trap,


you know, trapped orders.


Um, so those are kind of the main four


that I have used. Um, I've probably used


every single one of them at some point.


Um, other than like the FVG,


you know, of course, I will have them


marked off on my chart. So, if I see


price coming down and I'm curious where


it's headed, I'll have them marked off


and be like, "Okay, well, it's just


heading to fill those orders in the, you


know, the FEG." So, you know, I probably


kind of will mix in all of them at some


point to where, you know, if I see a EMA


test, it's pulling back into a fair


value gap.


you know, the fair value gap may be


sitting next to a support or a


resistance level and then I see a


strong, you know, a wick rejection that


kind of looks like to me it's probably a


liquidity grab and, you know, so if I


kind of see all of that stuff


happening, then, you know, that's when I


will wait for my confluences and kind of


decide if I want to jump in on the


trend. But all of those have worked


really well for me.


You know, especially with the way that


markets have been here lately where it's


like once they take off in a direction,


it just like goes and you feel like you


have missed out or um


you know want to like jump in in the


middle of it, which is you do not want


to do that. So, um, you know, just kind


of use any of these in a continuation or


a big impulse move. Um, you know, to


either get in or like I said, I've used


some of these to stack


if you're kind of, you know, ever


curious


when you should stack your orders.


Um, okay. Let me look at the chat. Y'all


have any questions on that?


Where would you put it for the pullback


to the 21? Let me get that pulled up.


Okay. So on say if I was on doing it on


the 15m minute and I wanted to wait for


a pullback come up above the nine


I preferred this one to close. So even


though this is like break of structure I


would probably just get in just as soon


as that closed. So I would want my stop


loss below


definitely the candle that comes down


and retest the 21. But depending on you


know like a support or resistance since


say this one there's not one except for


down here and that's way too big. then


I'll either put it below this fractal


um or depending on where my takerit is


and how the RNR, you know, cuz I


definitely want at least a one one. So,


you know, it would have to be at least


right there.


But if I had


maybe just was aiming for this one.


Actually, no. That's way too close. I


wouldn't do that. But depending on what


the RNR is,


it would be better if I could get below


these candles. But if I couldn't, then I


would definitely want to be below this


one, the one that came down.


to that 21.


I would want to be below that.


And that's where I would just kind of


I don't know determine


if I even was going to get in it. Um


I don't know what that just did. I think


I was closed out of that.


Um,


you know, that's where I would kind of


decide depending on what the RNR would


be on if I would set it or not.


Get back to these notes so y'all can


see them.


All right. Well, does anybody have any


questions about any of those or about


getting in on a continuation,


you know, after like a strong


um impulse move?


Well, that's good.


Hey, and I know a lot if you are


watching like the recording, just let me


know in circle if maybe you, you know,


have any questions


maybe regarding any of these or


something that you use that may be


different. But I think these are


probably the only ones that I have ever


really used that I've had good luck


with. So,


um, so yeah, just try those out. You can


go back and kind of look, um, you know,


not necessarily back test, but go back


and look, you know, and see, okay, if I


just try the 921 EMA retest,


it goes my direction


this many times, you know, or fair value


gap pullback. if you want to try that


and kind of, you know, make notes and


journal of which one you maybe have the


best luck with. And also depending on


what time frame you're trading on. So it


could be different from the 1 minute or


if you're waiting for the 15minut you


know it these could look different on


each time frame and some might work a


little bit better on you know lower time


frames that may work a little bit better


or be a little more um


you know just hold more weight with like


maybe the five or the 15 minutes. So,


kind of decide which one you want to


use, play around with it, even if you


jump into your practice account and kind


of go from there on which one you want


to use.


Okay. Well, um if we don't have any


questions on that, I did want to um


go through on our the post that I did


for um if you were staying disciplined


or not.


So, I wanted to kind of just see if, you


know, you were kind of sticking to the


um the like October challenge of one


pair, one time frame.


You know, strategy, one session of


course is better, but I put on there


that it wasn't like required. Um because


obviously y'all see me kind of bouncing


around. I will always execute on the one


minute, but I'll sometimes confirm with


the other time frames as well. So, um


but I wanted to just kind of reward


um somebody who has been doing that. And


I know a lot of y'all have said that you


have even noticed a big difference once


you kind of like honed in and picked one


of those and weren't like bouncing


around. I know for one it's really good


for you know just your anxiety your you


know mentality stress levels or it is


for me anyways to not feel like you know


I've got to hop over to NAS and I got to


see what my entry is doing there and


then hop over to gold and see what you


know to where I'm not bouncing around um


you know to different charts. Um, and I


kind of even thought of that this


morning on like gold and NAS when I was


flipping between those two. It's like


NAS was testing my 4hour resistance, but


gold was testing my 4hour support. So,


even though I have them labeled, you


know, on my chart and I know which is


which, if I'm flipping between those too


fast, sometimes I like could see how


easily I could get confused and like


think that gold is testing a resistance


area, you know, or something like that.


So, I feel like it really takes me a


minute to like study the chart and okay,


I know on the higher time frames we're


doing this or we've had five, you know,


bearish 4hour candles, so I feel like we


might get a pullback. So, I feel like I


know what each time frame is doing and I


want them to all pretty much align


um you know, for the most part. I know


there is some counter trading going on


with scalping, but for the most part, if


I know that we are in a very bullish or


bearish trend, I know not to go against


that for too long. So,


just having one chart pulled up will


help so much. But um but yeah, so I


wanted to uh reward that and give, you


know, somebody


3 months uh free subscription. So


I just got a hat and I just wrote


everybody who commented in there. I just


wrote your names on a little post-it


note and


just going to randomly draw one.


It was funny. I was going to like stick


these like


do something with like that support


member or the bear and I was just like I


better not do that. Okay, I'm just going


to grab one.


Melanie, I don't know if you can see


that or not. That might be backwards,


too.


And I don't know if she's on the call,


but um but if not, Melanie, I will um


I'll get with you and circle. I'll send


you a DM and just kind of let you know


how I'll do that. But but yeah, so 3


months um


you won't have to pay for your


subscription. So I'll kind of keep doing


these. I know. Um


like the one I don't remember what it


was called now, but the um the golden


whatever


I'm going to continue to do that one and


then of course this one I want to


continue to do. So I just want to reward


you guys for you know I see your hard


work. I know you guys are probably


seeing it, you know, reflected in the


charts and


just want to kind of make sure that


y'all continue to


um


kind of just stick with your rules. So,


if I have to reward y'all for that, then


I will and I want to.


Um, I did see a question in here that I


wanted to touch on regarding liquidity


suites, but let me get back to that.


Uh, okay. Tammy had asked what time


frame I watch for the liquidity sweeps.


Um, you can kind of see them wherever.


Of course, I like to watch them on the 1


minute just cuz that's the time frame


that I trade on.


And I'm going to try to see if I can get


back to this area


on that lower time frame.


maybe.


Okay, here we go.


So, you can kind of see


if I was watching this on the one minute


time frame.


You can kind of see this comes down.


We have a rejection wick and then


immediate,


you know, big green candle.


I'll kind of see if I can get to it.


I know there's got to be a way to kind


of lock that in, but can't remember how


to do that right now.


But I'll show what it looks like on five


minute.


So you can kind of see we had the


rejection wick followed by


an immediate


bullish candle.


And then of course the 15 minute.


So you can see rejection wick


followed by a bullish candle.


So, I feel like the liquidity grabs um


you can almost see the


just the the wick the rejection wick a


little bit better on like the higher


time frames like the one minute. Um,


well, I know it's going to reset, but


you know, you'll see a lot more of like,


you know, just the little one minute


candle. So, it won't be like a wick and


then like an immediate, you know,


uptrend again. But um you know so if you


feel like you are maybe seeing the


rejection wick depending on what time


frame you're on then you know you can


hop over to maybe like a little bit of a


higher time frame and see if it is


giving a rejection wick or not.


So even though you can see


a rejection wick even on the five minute


but you know a lot of times you'll see


like a little bit of this on say the


five three or one minute. It won't be


you know just wick and then come back


up.


So if you're seeing that, you can always


just kind of confirm on a little bit of


a higher time frame.


All right. Well, I think um if y'all do


not have any questions,


then I think that's it. Um, like I said,


if you are watching this recording and


have any questions regarding any of


these, just pop it in circle and, you


know, tag me. Um, and we can, you know,


kind of maybe go through and find more


examples. Uh maybe even on like


tonight's call if I see any of these


depending on what like gold and NASDA


does throughout the day where we can


maybe see one in the live market and I


can mark those off and you know we can


kind of


go from there. you know, if there's one


that maybe you are thinking you want to


use or you just want to see maybe a


little bit more of.


But other than that, just let me know if


you have any questions. If not, I will


see you guys on tonight's


scalping call and um we'll see what the


markets do throughout the day. All


right, guys. Well, have a good day and I


will see you on tonight's call. All


right. Bye.$video_18_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_18_summary$Shea shows how to get comfortable trading with the trend, including entries that happen after the move has already started. The lesson is about using pullbacks well instead of feeling like you missed the trade.$video_18_summary$
      ELSE summary
    END
WHERE sort_order = 18
  AND title = $title_18$Trading Continuation & Trend$title_18$;

-- Backfill watch-page content for lesson 19: Lock and Reload
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_19_transcript$All righty. So, um today I'm going to do


um


little bit of a a different kind of


call.


So,


I want to


not necessarily add any more rules. Uh


because I don't want y'all to um you


know or us just to kind of set too many


rules for ourselves and almost hinder or


kind of go the the wrong direction. Um,


but I I do kind of want to do a call to


go over more of like um discipline and


emotional control call I guess because


I've noticed a lot um in circle of


course I know I do it. I know just all


all of us do it and I think it's just


kind of a phase that we all need to go


through. But a lot of times whenever


you're losing a trade, it's not because


you're not understanding price action or


you're not understanding what you're


seeing structure-wise or your


confluences aren't there. Um, you know,


it's not necessarily from any of that


stuff. um it's more that we're losing


control in the middle of the trade. So,


um, you know, a lot of times kind of


what I'm seeing is, you know, you will


see a a good clean setup. You know,


especially if you've shared screenshots,


I can see exactly what you're seeing.


You know, confluences are there. Perfect


entry. I agree with it. I would have


even set or I may have even set the same


entry that you did. Um, but of course,


like we all know, once we get triggered


in and once price starts, you know, we


get a green number, we're in profit. Uh,


we all know that feeling, our heart rate


starts going up.


you know, you start immediately


thinking, I don't want to give these


profits back. What if it reverses? What


if this green number turns red? And you


just start, you know, getting in your


head. And we just know we all think the


same thing. Um, and so what a lot of


times that causes you to do is move your


stop loss. you want to immediately


protect profits, move your stop-loss


maybe a little bit too soon,


you know, or you just completely close


the trade out, you know, once you maybe


start seeing a little bit of hesitation


immediately, close it out or of course


just have it at break even. And you


know, then of course price will retrace


like we know they always do. and it


knocks us out, you know, knocks us out


either at break even, maybe a little bit


in profit depending on where you had


your stop loss, and then of course we


watch it go right back up to our initial


take profit. But, and I think that's


okay cuz I know for me personally, I do


that quite a bit. depends on what pair


I'm trading, how well maybe I trust it,


depending on if there's news, if we're


getting close to New York open, whatever


it may be. Natural gas, I am really


quick on moving my stop loss to break


even. Uh, and that's okay. If you do


that and you're okay doing that and it


coming back, retracing, hitting your


stop loss, whether it takes you out at


break even, whether you come out, I


don't know, $5, $10 in profit, whatever


it may be, and then it goes to your


initial take profit and you beat


yourself up too much. That's what I


don't want. Uh because I think for me


whenever I do that I am more willing to


get knocked out with a little bit of


profit and then just getting back in.


But I'm more okay with that situation


than for it to go and hit my full stop


loss. even if I know that maybe I'm not


risking too much and I, you know, would


be okay if it did go back and hit my


stop loss. I just prefer it to not. And


so for me, I think I am more okay with


getting knocked out at break even or a


little bit in profit and um


and then just getting back in. than for


it to go and hit my full stop loss. So,


I'm more okay


with that situation. But if you find


yourself really kind of beating yourself


up for moving your stop loss too quickly


and then watching it go to your takerit.


If that affects you in a negative way uh


more than if you just left your initial


take profit stop-loss, didn't touch it,


set it and forget it and it came back


and hit your full stop loss.


So, kind of uh really dig deep and try


to decide which one you would prefer.


Either get knocked out, break even a


little bit in profit, or leave it alone.


And if it came and hit your stop loss,


you would also be okay with that. uh


because I just don't want you to beat


yourself up so much by moving your stop


loss up that you kind of carry that into


your next trade. Um so that's kind of


what I've I feel like I've been seeing a


lot of and like I said, we all go


through it. I have done it. It's very


normal. Uh we just don't want you to get


stuck here. So, what I'm kind of wanting


to introduce to you guys today, it's not


necessarily


a, you know, fixing the charts. We're


not going to tweak anything with our


strategy. Everything is going to be


exactly the same. Our confluences are


still going to be the same. Uh, but what


I want to fix is the behavior that is


going on inside the trade. Because like


I said, it's not that you don't see a


good setup, that you're not executing


when you should, that your stop-loss


take profit


isn't where they need to be. It's none


of that. Um, it's more a trust a trust


thing. It's a trust with the markets. is


to trust with maybe your own analysis,


you know, and then once you kind of get


in that distrusting loop, it's really


hard to get out of that. Um, which is


what makes us immediately move our


stop-loss up because we we don't trust


something. Even if every confirmation in


the world is there, as soon as we get


triggered in and you see that little bit


of retracement,


immediate panic sets in and and it's


very common obviously uh because our


brains, you know, we just our brains


want certainty. So, you know, even the


floating profits feel great as long as


it's green.


we feel great.


Logic will tell you that we all think


the same way. Um, as long as we see a


positive number, then we're good. you


know, we feel great, we feel on top of


the world, we don't feel stressed out,


and then as soon as we start seeing that


pullback, it feels threatening, you


know, it feels threatening to our our


profits. And so I think just naturally


our nervous system,


it just tries to protect us. And so,


you know, we immediately start


panicking. We start stressing and we


want to do whatever we can to eliminate


that. And but, you know, we got to


remember that by, you know, the


protection without having structure


behind it can it just turns into


sabotage. So, we're either sabotaging


our trades by moving our stop loss up


too quickly, getting knocked out, which


then frustrates us. So, then that starts


sabotaging


ourselves. Um, and we get frustrated, we


carry that to the next trade, so on, so


on. Um, so, um, and before I get into


what exactly I want to kind of introduce


to you guys, I do want to be very, very


clear that if you do decide to use this


um, that it you have to be structured


with it because if you aren't, it could


definitely turn into panic trading and


obvious Obviously, we don't we don't


want that. So, uh you know, play around


with it in a practice account or a demo


until you one get comfortable with it.


Um two, know that it will help you. We


want it to benefit you, not do this and


turn into, you know, a panic closing out


trade, all that stuff. Um, so and if you


are already setting take-profit


stop-loss and you're able to set it and


walk away and not, you know, not


micromanage it and just let it either


hit your full take profit or your, you


know, full stop-loss, whichever one it


is, like whatever happens, you're okay


with either way. um then you don't


really need to mess with tweaking this


um you know or doing this tweaking


anything that you're doing because


that's the end goal. That's what we want


to get to. Um, but of course, if you're


finding that you're moving your


stop-loss too soon, um, you know,


closing winning trades out, uh, out of


fear, um, then, you know, or watching a


green trade turn, you know, to a


negative trade because you froze and


feared or whatever, then, um, then I


want this to kind of be maybe a a bridge


to get you from not trusting the charts


or whatever that is uh to trusting it.


Um,


okay. So, let me


let me get this chart pulled up real


quick


and then I want to I'm just going to get


this pulled up and then I'll share


share my screen.


Sorry, I had to really like get zoomed


in.


Okay.


Okay, there we go. Okay, so I'm going to


call this um the lock and reload tool.


Um,


sorry. Let me get this Zoom


screen out of my way.


Okay. So, um, real quick,


I'm going to get this pulled up. So, I


will share this in circle after the


call. uh because I want y'all to either


print it, have it on your screen,


however you need to kind of remind


yourself of how you're going to use it,


the rules, all of that. Um so, okay,


first obviously a clean setup is


required. So, we want to start it just


like we do any other trade. Whatever


your confluences are, whatever time


frame pair, you're not going to change


anything with your strategy. Uh so, you


still want to see a good clean setup. Um


if you don't see one, obviously, we're


we're not going to set that. We don't


want to set bad trades. Um, and you're


going to keep your original take-profit


and stop loss wherever you initially


would have those, whether it's, you


know, um, like, of course, for me, if


it's a support and resistance area, the


previous low before that, all of that,


wherever you initially set it, that's


where I want you to keep. Uh, so we're


not, of course, shrinking our takerit


out of fear. We're not going to well


instead of a one one let me do a one to


you know.5 or whatever. We're keeping


our initial whatever you normally do. If


it's a one one


to two keep it. Um same thing we're not


going to move you know our stop loss uh


to make it a less amount but it's a


little in the danger zone. We want to


keep it safe just like always.


um structure decides where our


takeprofit and stop loss is not comfort.


So, you know, well, I feel like my stop


loss needs to be here, but it makes it


to where my stop loss is $100. I don't


feel comfortable with that. I feel more


comfortable with $50. So, I'm going to


move my stop loss up where it's a little


more dangerous to put it here, but I


feel more comfortable than don't set the


trade. We want to set it where it's


safe. And again, if you're risking too


much, um, you know, or feeling a little


discomfort with that, then you're


risking too much and either go to a


different pair or go down to micros, one


micro, whatever it needs to be. Um,


okay. So, uh, so lock in profits, the


lock part. Um, you may lock profit when


price makes a strong push. Uh, and I'll


show you examples on the chart. Um, you


see hesitation or reaction or a micro


micro structure forming. Um, or you feel


yourself starting to manage the trade


emotionally. So, if you're starting to


feel that you're getting almost like


panicked and you're not moving your stop


loss because


anything else is telling you, there's


not a a fractal to move up to. Uh you're


not at a one one or whatever kind of


structurally would tell you to move your


stop loss up. You're not doing it for


that reason. You're only doing it


because you're starting to that fear is


starting to creep in. Um, so or you hit


your preddecided number, which I'll go


into that also. Um,


sorry, this thing is making it to where


I can't see this. Um, and of course your


preddecided number. So whether you have


a head of time, if I hit $50 profit, um,


I'm going to close out. I'm going to


lock in those profits.


But you're going to think of that number


ahead of time. You're not going to


decide once you're inside of the trade


because that's where you risk the


emotions setting that predetermined


profit amount and not structure. Um,


okay. So, and then of course the rules.


I use rules lightly because I just said


in the beginning call I don't want to


set rules. Uh but I do want you to kind


of have like the guard rails I guess. Um


and of course it's not permission to


micromanage your trade.


It's just permission to execute with


control. So there's a reason why you're


doing it and we're leaving emotions out


of it. Okay, so reload basically


re-entry into a trade only if the setup


still exists. So, you know, this is


where I want you to kind of write down


on a post-it note on your chart


somewhere. Um, is the structure still


valid? If you were just looking at a


chart, would you still agree that you


would set say a pending buy? Is


everything still valid? Um, you know,


and then of course whatever your


confluences are, if it's the EMAs, if


they're still, you know, they haven't


crossed yet, separated, whatever it may


be, um, have FGS been filled, if you use


those, um, if yes, then, you know,


reenter on confirmation. If no, then


you're done. Then, you know, walk away.


Don't even look at getting into a, you


know, re-entry on that trade. Uh, not


revenge, not FOMO. We're going with


confirmations only. Um, and one lock per


trade setup. So, you know, you're not


going to, and that's where the kind of


chaos can come in. Uh, you're not going


to immediately every pullback reenter,


re-enter, re-enter. uh you're just going


to make it one decision and then you're


going to pause, reassess,


and it'll eliminate that emotional


chaos. Um and of course, this training


is not forever. Um we've got to remember


that. Um our end goal like always is


still fully take profit discipline. So,


wherever we set our takerit and our stop


loss, we want to let it go. Uh, so


that's where we want to still, of


course, get to. Um,


but sorry, I had to get back on this


screen so I couldn't see this bottom


line. Um the lock and reload is to build


confidence


uh not shrink ourselves down to smaller


traders. Um okay. So now I'm going to


get this chart pulled up and kind of


show you examples of what I mean. Um


okay. So, I just found an entry where I


have my stop loss


below previous low below this, you know,


support or resistance area and take


profit. I just said a one one.


So this first one


on


get up here where you can see this. So


this first one right here is the ideal


one to one hold. So that's what we want


to aim for if we, you know, kind of been


distrusting of the markets, the news,


ourselves, uh, because of something


happening and we we then in turn start


kind of sabotaging. we bring all of that


negativity into our next trades and you


know for whatever reason you kind of


just created that distrust with yourself


in trading. Um you know but we want to


get back these are kind of baby steps


that will get us back to trusting all of


it. Um


and so this first one uh the holding one


to one that is what um you know mature


execution looks like. We want to get to


letting a a trade be whatever it is. if


it turns around and it hits our stop


loss, it wasn't because, you know, of


something that we misread in the


markets. It's just happens, you


know. So, um, but we have to be okay


with whatever our stop-loss amount is.


It's okay if it hits it. Um, and of


course, if not, then don't set it. Move


to a micro. move to a less expensive,


you know, pair, whatever it may be. But


whenever you set a trade,


we need to be okay with that. That's the


end goal still and always. Um, okay. So,


take profit, stop loss. We set it, we


walk away, we don't touch it. Uh the


second one of course is what a lot of us


are doing right now. Um and doing it for


the emotional


reasons which is where sabotage can


creep in. Um so it's not necessarily


a you failure, a strategy failure.


It's discomfort. That's it 100%. It's


just discomfort. That's what makes you


move your stop loss um to make yourself


feel comfortable. But then of course


where it turns sour is whenever price


retraces and knocks us out at break even


or profit wherever you put it. And then


we see, you know, so say if we,


you know, got triggered into this trade


and then move our stop loss wherever you


may move it. Uh for me, of course, if I


ever move my stop loss, I always go a


little bit in profit. So if it does


knock me out, I don't want to just get,


you know, knocked out at zero. Um, even


if it's $5, 10, $50, whatever it may be,


I will always move it in profit. Um, so


say if you move this up in profit, of


course, price does what it always does.


We had a retracement, knocked us out,


and then we watch it go right back up to


where our takerit was. And that's where


you start kicking yourself for doing


that. Um, and


that's where revenge trading can come


into play. Uh, because you're you're


pissed off and you know, you want to get


back in the, you know, the trade cuz,


oh, it's it's going up now. Let me hurry


up and get back into it when you don't


really have that,


you know, that micro structure showing


you to get back in. You just hop in. you


know, sometimes on a really big green


candle. So, you know, you panic


immediately, get back in. Of course, now


your stop loss is probably a little too


big. If it's going to be in a safe zone,


which would be down here, you know, now


maybe your entry is up here. And,


you know, then it's just riskier.


So,


um,


you know, you get in panic-wise, we


don't want to do that either. Um, and


then of course the third one is the lock


and reload. Um, so


whether you are going in with one micro,


I know a lot of you are already


initially going in with two or three


micros. Uh, so that's where you could


use that in your benefit to where you're


not closing out your full trade. Um, but


so say you go in


to micros and you already say have your


predetermined


amount of if if I go $20 in profit,


I will be okay locking in those profits


and then reassessing it and reloading.


getting back into the trade or if you


are going in with say two micros then


you will lock in the profits of the one.


So you know basically a a partial take


profit. Um


so


you see price pushes into profit.


I'm going to move this back. These boxes


really get in my way.


Okay, so of course we see we got


triggered in. We see a good push. Price


moves uh pushes into profit. We see a


small hesitation.


Oh, let me go back here where we would


have gotten triggered in.


Okay, so we see a small push.


We see a little bit of hesitation.


That's where you can decide


with that hesitation. I'm going to go


ahead and take profit on


one micro. If it's not whatever your


predetermined dollar amount was, uh


we'll say with two micros, let's go with


20 bucks. Um if you didn't get that


here, then you just hold it. When we see


this push right here, this probably gave


us that $20 predetermined amount and we


start seeing this hesitation. So, we


start seeing price pushed up. We see it


pulling back with this wick. That's when


you decide, I'm going to go ahead and


either take partial profit on one micro,


leave the other one to continue to ride.


Uh, but I'm going to lock in profits on


this one micro. Or if you're at that $20


profit and you're only in say like one


micro or one mini, but where you can't


take profit and let another one ride,


then you just close out the trade. You


take that profit, lock it in, and um


yeah, so lock full, close out the full


amount or partial and leave one running.


uh but you see that structure is still


holding


and say if you get another clean entry.


So depending on where you would have you


know gotten out at um whether it is a


re-entry


at a EMA pullback. So if price pulled


back to the EMA and then you started


seeing price go back up then you know


back to how you normally would have


gotten in a trade. So if it would have


been say this break of structure


um you know after the pull back into the


EMA then that is where you can get back


into the trade. But only if everything


is still telling you that we're still in


a bullish trend. Um, you know, of


course, like if you were watching it


say right here and you start seeing the


EMAs cross or a


um a lower low, you know, things that


are going opposite, then obviously you


you want to wait and reassess it until


you have a good clean entry all over


again. Um but


you know whatever you need to decide


ahead of time


especially your uh predetermined


amount that whenever you see that you


are good locking in those profits and


you know even if you need to start


little uh by I don't know 5 $10 I know a


lot of times with these micro s uh price


can move, you know, a little bit of a


distance to give us that $10 profit and


that's fine. Lock it in. Close out the


trade cuz you need to start training


your brain to trust yourself, your


setup. Even if you don't let it go to


your take profit initially, we'll work


our way back up to that. But we need to


see that we are profiting. Uh so it's


kind of like a few calls back whenever


you know I was wanting us to take these


little payouts you know kind of getting


past that payout block which I still


want you guys to do that and I don't


know if you have or you haven't


but I still want you to do that and this


kind of goes along with that. So, we


need to start training our brains to see


these little profits. And I know


sometimes seeing, you know, well, it's


only5 $10, that's not much profit. But


over time, you know, we need to see


these little profits because that's what


will build that trust within us. So, you


know, you may decide $5 this week and


then you start seeing those profits.


Even if it's your account growing $5,


you know, at a time, we know obviously


that will compound.


I mean, by the end of the week, that's


an extra $20. If you do $5 and that's


each day, not even each trade you get


into, but each day, then I'm telling you


that will tweak something in your brain


and it'll make it to where you you trust


your setup cuz it's like, okay, I saw


this setup and I was correct. Price did


go in profit. I was able to make $ five


dollar off of it and it triggers that


reward part in your brain and makes it


to where you'll start trusting yourself.


So, you know, I saw this set up. I was


correct. It didn't come and hit my full


stop loss or I didn't move my stop loss


from emotion emotions and panic. Um, I


closed it because of something I had,


you know, determined ahead of time. I


knew if I saw, you know, $10, $20 in


profit, I was going to close it out and


I stuck with that. Um, you know, so you


just want to reward yourself for


sticking with what you had decided


before you even got triggered into the


trade. and logic made the decision and


not your emotions. And then that'll make


it to where the next week you'll be able


to hold out maybe a little bit longer


and instead of, you know,5 $10, you hold


out to 20 or $30. And you'll kind of


notice that each time you do that, you


are able to gain a little more trust


with the charts, the market, yourself,


whatever it may be. and and then


eventually you will be right back to


holding out the whole trade. You know,


setting your stop loss and your takerit,


not moving it at all and


just set it and let it go. and you know


it hitting your full take profit or of


course because we just know that things


can happen or it turns around and hits


your stop loss. But either way, you're


okay with it because you've trained


yourself to trust your assessment of the


chart and you were correct. Even if it


hit your stop loss, you were still


correct. Um, so, um, I want you guys to


just try doing this for,


I don't know, the whole month of March.


Definitely a week. Um, you know, again,


if you want to try it in your um your


practice account, you can. But either


way, it doesn't really matter because


you're not changing


anything with your strategy. I just want


you to really practice not moving your


stop loss up out of fear and because of


emotions. I want you to


either move your stop loss up, take


profit,


you know, lock in profit, reload, get


back into it. I want you to do that


based on your strategy because you told


yourself you were going to do this and


not because of emotions. So do that. I


want you to journal it. Maybe you know


why you took the profits, what you were


seeing. Uh if it was hesitation,


if it was um you know you started seeing


the a little micro structure forming, uh


write down whatever it was that made you


lock in profits and or get back into the


trade and maybe that second one you


write it to that full initial take


profit. Remember, we're not moving any


of that stuff. We are keeping keeping


all of that the same. It's just what we


do in the middle. So, lock in profits,


get back in because structure still said


it's a good trade, and then we ride that


up to that initial take-profit amount.


Um, okay. Let me look at the chat real


quick.


So, just confirming, would we only take


profit if we felt the need to move our


stop-loss early and we would have


decided beforehand what number that


would be? Yes, that's correct. Um, so,


excuse me. Yeah. So, if you feel like


you are um you know, you're in profit


and you're kind of feeling that emotion


of I need to move my stop loss up


because I'm starting to panic. It's


starting to either, you know, pull back


like right here. Maybe you see this


pullback. You're starting to see kind of


this hesitancy.


And so, you know, we immediately will


start thinking it's getting ready to


reverse. You know, I got this wrong.


It's going to turn around. It's going to


immediately hit my stop loss because,


you know, something about this was not


correct. You know, and I know we always


go to I was wrong. It's not the market.


Um so yeah, if you start feeling those


emotions come into place and you are at


whatever your predetermined


um you know profit target I guess is


then go ahead and take those profits and


um you know and just remember


you can just get right back in


you know and the predetermined amount of


course isn't like the initial take


profit amount.


It's in between. So we want to find a


predetermined


dollar amount in the middle of the


trade. So, not our stop-loss, not our


take-profit, but somewhere in the


middle, if I start feeling panicked or


if I start seeing, you know, hesitancy,


whatever you kind of decide ahead of


time, then as soon as you start feeling


that, take those profits, lock it in


place, and then just reassess it, you


know. So maybe you know once it's kind


of hesitant


um or hesitating and you know if we see


it say break structure then I will be


okay getting back in and I'll know that


we just needed to range for a minute


then take your profits and you know look


at it kind of if you need to go through


all your confirmations again your


confluences Okay, EMA is still above.


We're still getting, you know, higher


lows,


um, you know, break a structure,


whatever it may be, then, you know,


okay, I'm going to set another pending


right here. And then if that gets


triggered in, then you're just going to


write it up to your initial take profit.


uh because we just want to see that our


initial,


you know, assessment of where we should


put our takerit and our stop loss was


correct. So, if you were to get in here


for your second reload trade, you don't


want to start another one to one and


then try to, you know, hit a takerit up


here because then that's just going to


essentially cause more panic cuz now, oh


god, now it needs to go further. We just


want to get to our initial take profit.


And like I said, we just want to slowly


start training


our selves to


keep our initial,


you know, setup and and you will just


kind of train yourselves by slowly


rewarding


yourself with profits in the middle of


the trade, you know, cuz somewhere in


the middle, that's where we let that


panic


set in. And so we need to reward


ourselves


somewhere in the middle. And that little


reward to our brain is what can help get


us to that initial take profit area. And


you know, then like I said, if you need


to work your way up, $5 profit this


week, $10 profit next week, you know,


just work your way up five $5, we'll


say. Uh because that's not very much.


So, you know, don't need to jump from $5


this week to $50 next week. Just do $5


at a time. And then,


you know, say by the end of 3 4 weeks,


you'll see that, you know, you're a lot


more comfortable letting it ride to say


$30 versus at first when it's $5, it


won't seem like that much. Um, but


that's where if you go in with two


micros or more, but at least minimum two


where you can not close out of the full


trade, but just take that partial profit


and just get that little bit of reward


to yourself of, okay, you know, I'm


going to let this second one ride the


full way to take profit, but in the


middle, I'm going to take a little bit


of reward for myself uh for just getting


the right setup initially and take that


profit, get your reward and then let the


other


continue on. Um but and that's where you


know that little reward system.


um


you know, whatever your predetermined


amount is when you take that profit of


say $5, then


go buy yourself something. Go buy that


coffee,


whatever it may be. go buy something


with intention and it will slowly start


building that trust again and make it to


where we're not doing that so much cuz I


feel like I mean the markets have just


been crazy here lately and so I know a


lot of us are like it's almost every


single trade that we get into we are


immediately ely moving our stop loss,


you know, because it's like we can look


at it and we're like, okay, we had a,


you know, a bounce off a support and


resistance. We have a higher low, we


have a W, EMA cross. I mean it can be


the full list of confluences is there


and as soon as we get triggered into the


trade all of that goes away and we


immediately


it's like we regret getting in the trade


and you know it's like as soon as we get


triggered panic sets in and it's like oh


my god what did I do I just got


triggered in it's going to go hit my


stop loss and and I know a lot of it is


more of the way the markets have been.


But because of that, we've trained


ourselves to have that not, you know,


that distrust


in whatever, you know, probably all of


it, but we have trained that into our


brains and it's going to end up biting


us all in the ass. So, I want us to


really start kind of working towards the


opposite. Um, you know, hopefully we've


gotten through the last quarter of the


year. We've gotten through January,


February, you know, March, we're clean


selling. So, we're going to start with a


clean slate and start


gaining that trust back. And I think I


think the easiest and the quickest way


to do that is by taking these little


profits.


Um, okay. Let's see.


I know how to take partial profit on


Trade Locker, but do not remember how to


on Trading View. Um, okay.


Let me


Get this zoom screen out of the way.


All right, I'm going to see if I can


quickly


I think last time I tried to show this


example, it it was not cooperating with


me.


Um, okay. So, let's see. I'm just going


to


Let's see. We will sell. So, say we're


we got in two


micro contracts.


Oh gosh.


Let me get on


Let me get on micro. And I'm in just my


paper trading, but still


Okay. So, sell go to contracts.


Okay, I'm going to see if this will


trigger me in just so I can show you


kind of real time.


And for some reason, I don't know why, I


just I never have like done partial


profit taking uh very much um


with Forex. I think I obviously started


doing it more whenever uh we all


switched to futures.


Okay.


>> Can I ask a question while we're


waiting?


>> Yes. Let's go right ahead.


>> Um what are um some brokers again that


you trust for Trading View?


>> Um so with Trading View, I am using them


for um my take profit


my prop firm.


Um I don't have a live account


with Trading View if that's what if


that's kind of what you were checking


on. Um


I was trying to think who


who I have heard of.


I mean trade of eight is on I mean you


can have just a trade of eight account


but if you're doing futures


you have to have quite a bit of money to


run futures.


Um, if you're wanting to do


I mean if you want to do just forex of


course there's always oda but I'm not


sure


outside of futures


of any


I don't know.


>> Yeah, I don't either. Yeah, the only


live that I have is with Trade Locker


and and I think because I'm kind of the


same as Jill is um to have the live


futures account


um


I'm like I don't know why I'm so like


hesitant because I just for one the the


amount that we've kind of heard that you


need and I think a lot of it is um to


hold, you know, during market close or


weekends or whatever, you need like that


really big cushion just in case,


you know, say market opens like it did


yesterday and they want to make sure


that you have enough to cover that if it


goes wrong. Um but yeah, I think um


I think like she said the trade of eight


um


and there's some other ones that I know


like others in our group are using, but


I think like some of them,


you know, it's like if you're in Canada,


you know, or something like that, the


ones that I don't think we have access


to. Um,


and then I just really haven't kind of


looked into into that very much.


>> Okay.


>> So,


>> yeah, I only have a Trade Locker account


as well, but I um I must have missed it


because I saw that you were trading or


some of you have been trading micro gold


and I can you do that on Trade Locker?


>> No, no, just regular


>> just regular u


gold.


Okay.


Um, so your micro gold is through your


prop firm.


>> Yes.


>> So,


>> okay.


>> So, on on Trade Locker, it's not


it's not like the micros and minis of of


futures. It's the X AUSD


or or whatever it is on Trade Locker.


Just a regular. Just a regular. It's not


not the futures.


Yep. Yeah. It's just the Forex Forex one


that you're um because you said you have


a trade locker one.


>> Yes, I do have a trade a live trade


locker account.


>> Okay. Yeah. So, anytime that I've am


trading on Trade Locker, it is just the


the gold one that Jill was talking about


the Yeah. X a X AU or whatever it is. Um


and then and then you just can go down


with um you know like 0.01


lots or whatever. So that's kind of how


you can manage that size versus like


micro and mini on futures is like a


preset


amount I guess. Um so that's just kind


of how you can play around with it on


trade locker.


Okay, thank you. Yeah,


>> you're welcome. Okay, so I'm going to


see if if this will kind of go down a


little bit more.


Um


on on


to where I can set this. And if not, I


can go ahead and just kind of show you


how to do it even though it's going the


wrong way. But so of course we're in a


sell. So say if I wanted to take partial


profit once it got say down here if that


was kind of my predetermined amount then


you kind of just set it up like you're


getting into a trade but you go


opposite. So add order. You want to


change this to one.


And then you want to


whoops, wrong one.


>> Make sure you grab the right one. I


think I did that last time, too. But


yeah, wherever you want it, you just go


opposite. So that's where you want to


buy if you're in a sell with one one of


them and it will take the profit


>> and you and you wouldn't need to set a


takerit or stop loss on that, would you?


>> Right. Yeah, you wouldn't need to. And


I was trying to think and I might be


thinking of


somebody else that was showing it with


their prop firm like it may have been


the X platform


and I'm not I won't go into it too much


cuz I'll probably just confuse but


somewhere there was a setting of


where you could choose like partial and


I might also be thinking of trade locker


where it actually worded it uh like


partial profits or whatever. But


actually the more I say that the more I


think it was on trade locker that they


had changed changed their settings where


you could choose to to take like a


partial profit. But yeah, so definitely


play with that one in um in like a your


demo or paper trading on, you know, just


randomly put yourself in like two of


them and then


wherever you decide maybe like midway


set a, you know, a pending buy or the


opposite and then watch to see if it


actually does throw in that profit.


But yeah, just kind of play around with


that because like I said, I don't take


partials very often. Um but but I do


know that you just said it the opposite,


>> right? Yeah, that help that definitely


helps. I think I'm I may stay with Trade


Locker then. Um because I I didn't


realize that you could only do micro


gold if you have a paper if it's um demo


trading or prop firm.


I thought that it was like your that it


was your live


>> a trade locker then.


>> Yeah.


Yeah. And I do


>> I do still want to,


you know, get a a live futures account.


I think the dollar amount is what um


yeah,


I don't know why it just it worries me.


And then I'm sure


a lot with, you know, the other ones


like shutting down and I think that was


kind of where I was like I don't know


which I say that but um


but even though I do have the live trade


locker one I know that I'm not required


by them to have a


you know minimum like $3 to $5,000


count. I think that maybe makes me a


little more worried. Um, so


yeah, I still do want to try to find one


that I'm that I'm comfortable with.


All right, guys. Well, can y'all think


of any any other questions that you


may have that that hasn't already been


answered kind of regarding all of this?


And again, I will share


this


in circle. That way if you want to take


a screenshot of it or you can print it


off uh just to kind of remind yourself


what what you need to make sure that um


you know I was going to say rules again


but yeah I don't want to


y'all to think that there's like rules


with it but just to make sure that you


are doing doing it the correct way and


not doing it with emotions, you know, we


need to make sure that we're staying


disciplined with it. Um because again,


if you


if you aren't careful, it can create


chaos and we definitely don't want that.


So, um so yeah, I will get this uploaded


into Circle and um play around with it.


If you think of any other questions,


definitely let me know and we'll kind of


just we'll work through something and


make sure that we're all on the same


page and that we slowly start getting


that trust back with the market. So,


we're not moving our stop losses based


on emotions


and then getting upset with ourselves


whenever we do that. So, all right guys,


well, y'all have a good day. Be careful


if you're trading in your live accounts


today and hopefully whenever we hop on


the markets tonight, things will be


calmed down and moving a lot smoother


for us. All right, guys. Well, I will


see you on tonight's call. All right.$video_19_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_19_summary$This lesson explains Shea's lock-and-reload approach for managing a winning move. You'll learn how she protects profits, looks for re-entry, and keeps structure on the chart after the first push.$video_19_summary$
      ELSE summary
    END
WHERE sort_order = 19
  AND title = $title_19$Lock and Reload$title_19$;

-- Backfill watch-page content for lesson 20: Live Trade Walkthrough
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_20_transcript$Okay. So, um I think in this call today,


I'm going to kind of just go over a what


I would consider a good trade versus a


not good trade and


maybe uh kind of train your eyes to


see the difference and um


and kind of go from there. So, let me


pull up my screen.


So, um I was trying to think of


something I could call them and for some


reason I at first went with um like


golden like I was thinking like my


golden retrievers. Uh but I couldn't


think of anything that was like, you


know, the golden would be like the good


trade and I was like straight alleycat


like I couldn't really like land on


something. So, um, so we just stuck with


a golden trade and fool's gold. So, um,


I'm going to kind of show you the


difference in,


you know, and it's mostly just your list


of confluences. So, um, of course, I


have these listed out right here.


support and resistance reaction 921 EMA


cross or W forming higher highs lower


lows whichever direction it's going a


break of structure change of character


and FVG getting filled. So, whichever


ones that you kind of want to stick


with, that you have, you know, luck


with, whatever it may be, um, have those


as like your talk maybe for and and try


to only take trades if those line up and


in whatever time frame you might be


choosing. So whether it's the 1 minute,


5 minute, 15 minute,


just stick with your confluences and you


know kind of really


practice your patience and not entering


into a a scalp unless you see all of you


know those confirmations. So um of


course this is kind of the order that I


look into. Um, I first want to look at


my support and uh resistance reaction.


Those are the areas I would prefer to


enter into a trade. Um, my 9 and 21 EMA


cross. I want to see that


MRW forming and then of course, you


know, higher highs, lower low or higher


lows if I'm in an uptrend. Um and then


from there you know I will still


consider like a break of structure if I


see it especially if it's you know say


in a little consolidated area then I


will see you know or want to see it come


up and break this structure. So,


um, and then of course I put fair fair


value gap on there, but


you all know that I don't always base a


trade, you know, just off that. But, but


I will peek. So,


okay. So, first I'm going to show you um


a fool's gold trade. So, it's where you


might see like some of your confluences


and you're almost like trying to


convince yourself that that it is a good


trade. It's going in a direction that


you might think it's going in based on


only maybe a couple of, you know, your


confirmations. Um, you know, or it's in


a messy structure. It's, you know, it


looks like this. It's a little


consolidated.


It doesn't have just pretty direction


that's maybe convincing you that it's


going in one direction or the other. Um,


and of course it's high risk, low


reward. So I'm going to go back here and


kind of pull up this one.


So this for instance, if you were to


maybe just be popping on the chart, you


know, of course this is at night, but um


if you were to see this and you know,


think, oh man, I'm going to get in this.


It's an uptrend. I see higher highs,


higher lows. Um and and you just get


into it almost just based off of that.


Um, you know, the EMA you can already


see is pretty far away. Um, but you


know, you may see this higher high and


you had a reaction off of, you know, a


15minute resistance area. So, you know,


if you were to immediately enter, say,


you know, right here, if we had this


little break of structure


and you just entered in and you really


don't take the time to think about the


bigger picture. So, you know, I put on


here that, you know, you had a reaction


off the 15minute time frame and that's


one good thing. You might have seen the


higher highs. That's another one. Um,


you know, break of structure, there's a


third one. Uh, but


even with those confluences being in


your favor,


you want to maybe just sit back and


think, you know, okay, we're really


close to a major support area. So, we


have this 4hour, you know, top


resistance that we're pretty close to.


So, we know we could get a reaction off


of that and it could potentially


reverse. So, just that alone would


maybe, you know, make you not want to uh


get in that. So, just kind of think


about that and


um you know, it's a little close to a


major support and resistance level. And


then of course you can see this lower


low that happened. So whenever you see


that that could be a sign of you know a


change of character. So it may be


starting to kind of uh signal that we


could be having a reverse. So, whenever


you see that, you know, maybe just wait,


you know, see if you're either going to


have a reaction off of this resistance


area,


um,


you know, and just kind of let more of


your confluences line up. So whether


it's a pullback and you want to wait and


see if your EMAs cross or you know just


continue to see these higher highs and


higher lows. So you know you can kind of


see this was a little risky low reward


also because where I would personally


place my stop loss would want to for


sure be below this low. Okay. So, if I


wanted my stop loss there where I kind


of felt a little bit safer, you know,


and I set my takerit at my 4hour


resistance, it's just there's not much


profit there. So, you know, also kind of


weighed that out.


Okay. So, now I want to show you kind of


more of a golden trade. So, you know,


this is the one of course where you want


to see more confluences. uh whichever


ones you go off of, make sure that you


can check them all off. You want to see,


you know, clean structure and of course


a smoother entry.


So, and of course, high probability and


lower stress. So, um I pulled up this


one down here.


So, you can kind of see we had a


reaction off of our 4hour support. Uh,


which, you know, is a very good uh


support area to get into.


uh even though I will get into them off


of my 1 hour and 15, but if I can ever


catch price and it's reacting off of a


4hour support, then that's even better


because obviously they hold more weight.


So, you know, if I see that it, you


know, came up and we had a, you know, a


retest of it. So, I had a, you know,


bounce off my support, major support.


Um, and then you know I'm starting to


see these higher highs come up and you


know of course I think I put this to get


in here but so you wouldn't have seen


this higher low but


um I also see a W forming.


Hold on. I got to get this out of the


way to get to my tool.


So I can see


this W


forming


and then of course we had a break of


structure. So whenever price broke above


these wicks,


then that would have been a good sign


for me to either enter or start watching


it. So


let me see if I can get back to it on


the one minute.


I know there's probably got to be a way


to bring it right back to where you


were.


Okay. So you can kind of see on the one


minute,


you know, even though this EMA crossed


right here,


I would have obviously waited until it


came up to this 4hour support. But you


can see that you know the EMA did cross


and then of course it broke the


structure on the 1 minute time frame


just shortly after it test you know went


above that uh 4hour support. So just


kind of depending on which time frame


you might be looking at um


you know with your confirmations.


Let me get this down where I can see it


again.


But okay, so for me, if I was to look at


this, it had enough of my confirmations


to go ahead and get me in the trade. And


even if I wanted to be safe and put my


stop loss below this area right here


and of course


I always usually put my takerit you know


at the next uh 4hour resistance if I


can. Um, so that would have been, you


know, a one to six, but I would have


been moving


my uh stop loss up with the one minute


fractals. So, I may have gotten stopped


out before it even got up to this area.


Um, but you can just kind of see how


much smoother, you know, that looks once


it kind of breaks out of this range


area. And you know, it just would make


me feel a little bit better versus this


one. You know, getting in almost at like


the tail end of the move is where I


would just want to make sure that, you


know, that I would be able to get more


profit than


than not. So,


so anyways, if you look at just kind of


the difference in those and kind of


train your eyes to, you know, maybe back


test a little bit and I know if you have


um trading view, you know, you can of


course do the replay mode and um


and then just kind of pick an area And


even if you go back to a certain day and


mark it off and then mark up your, you


know, support and resistance areas so


they match to that time frame and just


kind of look, you know, okay, I see this


is starting to give me confirmations.


Would I feel comfortable entering into


it? And, you know, mark it off. then hit


that replay mode and


just kind of continuously do that and


see if you know over time whenever you


see


your confirmations,


you know, if you can just pick them out


a little bit quicker and a little bit


easier and not get hung up so much on


just one or two and just immediate


immediately, you know, jump into it. So,


I just kind of want you guys to


create that muscle memory. Um, and then


of course, it doesn't always work out.


Like, if y'all were on the call this


morning,


you know, sometimes you see the


confirmations and,


you know,


I don't want to say, but just just


happens. I don't know. I It depends on


which pair you're trading. Also, um,


you know, NAS is definitely one that,


um,


you might want to wait a little bit


longer until you have some, you know,


more confirmations.


Um, also important to check news because


that can fluctuate it quite a bit. But


for the most part, you know, watch


around these resistance areas. you'll


see this accumulation


and then it'll kind of you know decide


which direction it wants to go and you


know that's where we just kind of


you know look at our confluences and


decide which direction we think it's


going to go in. Um so EMA cross I think


is a big one you know second to the uh


support and resistance. So


anyways, do you guys have any any


questions on that?


>> I have a question, Shay.


>> Okay.


um like on the one minute once it


crosses over your 4hour resistance once


it crosses over to the top do you wait


for a retest of that to see if it's


going to continue to go up or are you


okay with just the break of structure


and


you see what I'm saying like underneath


like underneath


>> are you talking about like they entered


the support


>> yeah like it like it tested It tested it


underneath the 4 hour, but once it


crossed over, do we need to wait for a


retest there, or are you okay with just


a break of structure and assume it's


going to go on up? I always like a


little bit of a retest. Uh, but


sometimes with like NAS especially, if


it goes above this support and breaks


structure, sometimes it can just have a


lot of momentum behind it to where you


might not get a pullback for a little


bit. Uh but yeah, definitely if you can


get a little pullback into it, then


that's even better, you know, cuz that


way you can see that it's coming up,


breaking structure, testing it, and then


coming back up. Um, you know, even like


two I would say, would be better, you


know, cuz that would kind of give you


your W. But, you know, if you can see a


W forming before that,


I'm okay with that. Uh, but,


you know, it's just kind of your risk


tolerance, I think, on, you know, if you


want to wait until you maybe get a


couple of retest, which, you know, you


can see if you waited,


you know, comes down. uh that one


doesn't quite, you know, come all the


way down, but it's still another


pullback. And, you know, if you feel


like maybe you want to wait until you


see a W forming


uh above the resistance, then you know,


you could still do that and then just


get in right here. But, but then, of


course, at that point,


it's by that 1 hour. So then I would


probably wait and see what it does at


that point. But but yeah, I think if I


see a W forming,


you know,


>> I just didn't know if the re if the


retest on the B uh underneath the 4 hour


and then it crossed over if that was if


that was good enough confir confirmation


or if we needed to wait on the top end


that but I see what you're saying with


the W.


>> Yeah. And I I don't think I necessarily


always do. It just maybe depends on,


you know, where this candle is that


breaks this structure where it's at, you


know, if it's fully like more above the


support. I you know if it's maybe I


don't know like say if this one right


here was above this wick I would maybe


wait and give it another candle to maybe


like fully break that structure. So you


know if I saw that above the support


then


that would be good enough for me. But


but maybe it's just because I


you know cuz it's NAS I feel like I I


know that pair. Uh but


you know I guess you never really know


know a pair uh obviously but um but yeah


I would just say and just depending on


of course what time frame you're on. So


you know if I jump to the five minute


You know, you can see whenever it broke


structure here,


you know, which would have been


more in that area,


you know, it's kind of the same thing.


You know, it came up and then we had a


retest and then, you know, depending on


where you whenever that happened of it


coming up and breaking this structure.


Um, you know, then I mean you still get


get in a pretty good spot with that


Nikki. Oh no, not me. Immediately


jumping in.


Yeah,


maybe not do that,


but I get that.


Let me go look at Bitcoin right now.


Of


course, my uh


my support and resistance is


not marked up on this one, but


boy, everything had a


crazy jump.


I'm not going to mark all this up. I'm


just kind of looking to see this


range.


Hey, I have a question.


>> Yes.


>> And I can't get my screen to share, so I


don't know. you just see a a black


screen. But anyways, um do you trade


from your phone or do you trade from


your computer? Typically,


>> I would say most of the time I probably


trade on my phone. Um, if I'm like in my


office and you know, I guess where I can


see it a little bit better, I'd probably


I guess prefer that just because like I


have a bigger screen over here. So if


I'm ever like back testing or anything


like that, I'll always want to do it on


my computer. But I do a lot of it from


my phone and maybe just so I don't feel


like I have to stay in my office is


maybe a big reason why. So I probably


have like carpal tunnel in my thumb from


it. But um but I've definitely gotten


into the habit of just trading on my


phone. I don't know. I guess I


>> I don't know why I do that. Maybe it


just makes me feel like it's a little


more passive.


Yeah, I guess I just asked because I'm


like, "Okay, I'm still new, so maybe I


need to like have a bigger screen so I


can like see it more clearly." I don't


know.


>> Are you Are you mostly doing it from


your computer right now or from


>> No, mostly from my phone, but I wondered


if it would help me. And I know some


people like use like an iPad if you have


that to where it's not like you're


necessarily lugging around a laptop or


whatever. Um, but of course the screen


is a little bit bigger than like your


phone. But I'd say it definitely takes


some time to like get used to it.


Sometimes if I'm trying to like maybe


move my stop loss up,


you know, or something like that, like


trail it manually. Um I feel like


sometimes it doesn't work that well on


my phone. But


I don't know what, you know, that most


might be like my phone cover or


something. I'm not sure. But um but I


think that's probably the only like


frustrating thing with my phone is if


I'm trying to like hurry up and like


adjust lines and it doesn't want to do


it fast enough. But but yeah, other than


that, um


I don't know. I've just think I've


traded with my phone for so long now


that it's just not that not that big of


a deal. it. But like I said, I'm sure my


hands and my eyes will not like it in a


few years. So sometimes if I'm in my


office, I will go ahead and like get in


the trade and then set alerts and and


then just peek at it, you know, on my


phone if my alert goes off.


Um, let me look at the chat. Uh sorry


already mentioned seeing these


confluences like the EMA cross MW change


character at higher time frame 5 minute


as well as the one minute would improve


probabilities too right yes I definitely


agree so a lot of times like you'll see


me you know like in the live I will pop


around like I'm kind of my chart goes


all over the place. Um, so I'll check


different time frames and of course I'll


like shrink my screen, enlarge it. Um,


but go into the different time frames if


especially if I'm ever uh, you know,


maybe like questioning


if I'm, you know, feel comfortable


enough just going off of my confluences


from the one minute. But if I'm ever


questioning it, then that's whenever


I'll usually hop over to the 5m minute


and maybe even the 15minut and you know


wait to see maybe like the EMA cross on


the 5m minute instead and not just base


it on the 1 minute. So yeah, I


definitely um agree Ellie if that's what


you were saying is you know just to kind


of compare and you know if you see all


of your you know confirmations on


multiple time frames then yeah that's


even even better.


I see that might be my problem too. I


might just have fat fingers and it's not


understanding where I'm wanting


uh where I'm wanting to adjust it to.


No, Tra, I haven't. So, those styllist


pins I have just never even used one.


But, um but I bet that would be a whole


lot better.


I'll have to look into that.


I think my husband uses one


maybe on his phone or like his phone had


like a, you know, a little thing where


like it popped out.


I have a hard time keeping up with my


phone. I can't imagine trying to keep up


with a stylus and my phone.


>> Yeah. And I think that's maybe why I


like the alerts so much is, you know, if


I'm at home or something and I don't


know, maybe sitting on the back porch


with my husband or whatever, and I I


just I don't feel like I have to really


do anything with my phone until my alert


goes off. And then if I'm at home, then,


you know, I could always just run in my


office and check it real quick. But um


but I do feel like it's getting,


you know, to the point to where I


probably need to slow down trading on my


chart.


>> Does your husband trade, too?


>> No, he doesn't. He has an account. Um we


set him up with all of that. Um and you


know, because whenever I was swing


trading, I always did the 4hour time


frame and I love that. I still do like


that time frame, but I don't don't


really trade it anymore. I pretty much


just scalp now. Um, but we were going to


have him, you know, do the higher time


frame and of course more just kind of


passive uh slow growth uh while I do the


scalping. But


I don't know his uh


he's just a busy body. So I think for


him if he's not at work, which


sometimes, you know, he's at work for a


couple of months at a time, then he's


home for a couple of months at a time.


But he just has to be like outside. So,


I think that's his biggest thing is


he just thinks, I don't know, I just


can't just sit and look at my phone or


be at a computer watching videos, you


know, stuff like that. He's got to be


like chopping down trees in the forest


or something. He's got to be doing


something.


But I think maybe uh later on if he ever


decides that, you know, he's ready to


give up on the oil field,


maybe he will at that time.


Okay. Fay. So, were you looking Oh, and


my lines are probably


not where they need to be


cuz I was looking at this and I was


like, "Oh, we're having a we're testing


that 4 hour support." But there's no


telling when that line was drawn.


Let me look at where this is real quick.


Might not be too far off.


So, I know the uh


I had this I think marked up.


Maybe it was in my top step.


And I know a lot of y'all were getting


in on that cell,


but maybe we're having a reaction and


going back up now.


Did you already get in this bay or did


you say you were just looking looking at


getting in it?


I mean, so far that looks really


>> I didn't get in it yet because I was


being patient and trying to take your


advice, but I was getting itchy.


>> I would be too. It looks It looks good


to me. Um, you know, of course this


4hour support. Um,


>> okay. The blue line.


>> Yeah, it's pretty close to that, but of


course that was Sunday. Now it looks


like it's going into consolidation. So


it's a good thing I didn't I took your


advice.


>> Yeah. I So maybe right here, Friday.


I don't know cuz I have this at Sunday,


but no, I'd probably leave it there


because it looks like it had some


reaction to this.


Yeah, I don't know. I mean, it


definitely looks good. I see, you know,


like a W on the five minute, but of


course with it being gold. Yeah,


>> I would


I don't know because by the time it


breaks this structure right here and of


course by then we may have a cross of


this it would be pretty close to you


know where I have that 4hour support. So


I would maybe wait and if you you know


>> wait till 4 hour. I don't know why I


don't have that marked off on I guess I


marked it off on something else.


probably trading view.


>> Yeah. And I would I'd maybe set an


alert, you know, around this area right


here and


and then kind of see what it does from


there.


>> Yeah, it may be it may be heading


heading back up after that drop this


morning.


>> But I do see what you're seeing.


>> It is kind of ranging right there. Yeah.


Oh, that's a good ways to go.


>> I know. I always


sometimes I definitely miss trading


gold.


>> Yeah, I think I would I think I would


wait on this one.


>> Okay, good advice.


>> Just to be safe.


Of


course, for me and gold, I'm like, let


me just wait until this 15 minute.


I want to be for sure. For sure.


All right, guys. Well, um, if y'all


don't have any more questions, I was


just going to pop back.


>> Hello, Shay.


>> Yes. Hey,


>> hi, it's Heather. I just have one


question about the break break of


structure.


>> Okay.


>> So, I was noticing on the NAS that you


just looked at the most recent structure


to break.


>> Is there do you only look at the most


recent one or like on this one?


>> This trade that you're looking at here.


>> Yeah.


>> You wouldn't look back another


structure.


I feel like I'm always waiting for the


the next structure to break, you know.


>> Yeah. No, on this right here, whenever


I'm looking um I usually try to go with


like the previous high. Um but of


course, like with NAS because it's just


a little um I don't know, more bipolar,


a little riskier I guess pair to trade.


Um, you know, I would like almost prefer


it to, you know, even come above like


these candles. Uh, but just it breaking


above this structure. Um, you know, so


which would be,


you know, once it broke above this


candle right here,


>> then that's usually enough confirmation


for me. Uh but you know, even if you


wanted to be a little more cautious and


just let it get completely out of this


zone, uh then you could do that. But


yeah, I don't usually go back too far. I


just want to look at the most recent uh


you know accumulation or you know this


range right here and


you know just kind of let it get out of


that


um most recent consolidated area.


>> Okay, great. Thank you. That helps.


>> You're welcome,


Jill. I have definitely done that.


Stretch your screen out. It's going


towards your stop loss. Make it look


further away.


That's funny.


Yes, Jackie. Let's see. Let me shrink


this down.


Are these the ones you're talking about?


>> Yes. Thank you.


>> Okay. You're welcome.


Yeah. And so if you guys want to um I


added a a space in the circle. Um and


I'll have to look. I think I named it um


something with homework. So if you


notice that trade lab. So, if you if you


want to if you kind of play around with


some charts and you're marking them up


and trying to find, you know, a a golden


trade versus a fool's gold, then, you


know, mark both of those up and maybe


list like your confluences, why you


would have taken it as a golden trade.


And then, you know, maybe if you found


another one that you would consider


fool's gold, you know, list out maybe


just how I did, you know, with this


little call out tool. um you know what


what made you initially think that it


would have been a good trade and then


versus kind of what you learned from it


based on what it did that ended up


turning it into a a not good trade and


if you want to you know mark those up


and then share them with the classroom.


So I know if you're in like trading view


and I know top is the same way but if


you click this little camera button you


can download the image. So,


um, if you want to upload those in that


section in the, uh, circle space and


that way maybe it can kind of help you


to get feedback from other people on,


you know, maybe they see something in


addition to what you saw. Um, you know,


or just kind of help maybe somebody else


out. Maybe somebody else will share a


screenshot that


you may have thought would have been a


good trade, but after they posted it and


you kind of see what you know what they


found after they dissected it, you know,


it may kind of be like, oh, you know


what, that wasn't wouldn't have been a


very good trade. So, um, that section is


there if you guys want to load up some


screenshots. And um and then I was going


to mention one more thing. Um


I know on Thursday,


sorry, Friday the 1st, um the trial


period is going to end and we're still


kind of um not 100% sure how that's


going to go. So, we're going to try to


play with it, but I just wanted to uh


kind of get with you guys ahead of time


and be patient with us. Um, I know one


thing is


if we wait and let it all transfer over


on its own, it's going to keep you in


the trial and and we can open up all


those spaces, but it's just going to be


um like two separate places. So, if you


guys know that you want to, you know,


stay and um just kind of upgrade your


subscription, then if you want to go


ahead and switch it yourself, and I know


in the um the circle space, let me get


that pulled up real quick.


Oh,


there it is.


um


over here.


Sorry, I got to remember where I put it.


Right here in this community connection.


This link right here. If you want to go


ahead and upgrade,


um you know, and maybe even like


Thursday the 31st, then that way we can


help you, you know, cancel the trial one


if we need to. Um,


but I think maybe that might be the


easiest way,


but if not, we'll still get you over


there. Um, you know, just be patient. If


it if something kind of goes a little


haywire and we're having to do them kind


of more manual, then


we'll get to everybody. Uh, we're going


to


get everybody's, you know, names first


just in case it completely kicks you


out. uh we'll get you back in there. I


promise. So, um just be patient. Um it's


going to be like a new learning curve


for us when the first happens, but but


after the first, we won't have to deal


with it anymore. So, um we'll figure it


out. But um but just wanted to throw


that out there to you guys that you know


I'll kind of put a little message out


before


just to remind you guys that if for some


reason can't have access we'll get you


back in and and I don't know it may


still let you DM me. Not sure how Circle


works, but if anything happens and


you're having any issues and you can't


get back into my space, um, see if you


can DM me still and and let me know um


you know that you are wanting to, you


know, upgrade but but maybe you just


like something happened. So, um, yeah,


either DM me if you get kicked out,


we'll get you back in, or if you're in,


you know, the circle still and just


having issues and not sure what to do,


then, um, you know, that's where you can


just maybe post in here and somebody


will get you fixed up. But anyways,


wanted to mention that. Just be patient


with us. And um Oh, okay. Julie was able


to DM. Okay, so that's good. Yeah. So,


for some reason it kicks you out while


you're, you know, transferring over um


just shoot me a DM and we'll get you


back in.


All right, guys. Well, I think that is


it for today. So, let me know if you


have any questions and of course if you


want to go find some, you know, charts


to mark up and post your golden trade


versus your fake gold and then we can


all kind of um give our opinions on it.


So, all right guys, well, I will see you


all this evening if you're jumping on to


the evening scalp with me and y'all have


a good day. Okay, bye.$video_20_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_20_summary$This is a real-chart walkthrough where Shea talks through trade quality, context, and decision-making in real time. It gives you a practical look at how the strategy comes together in a live session.$video_20_summary$
      ELSE summary
    END
WHERE sort_order = 20
  AND title = $title_20$Live Trade Walkthrough$title_20$;

-- Backfill watch-page content for lesson 21: Prop Firms: Pros & Cons
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_21_transcript$Okay. So, um I just of course did a word


document. Um it's kind of long. So, but


I will try to uh do a um like a Google


doc and upload it into circle so you can


kind of have all of this to look over


later. Uh because it was kind of lot. I


was trying to make sure I didn't leave


anything out. But um basically I just


kind of tried to do it in different


categories. So criteria as far as


transparency and clarity of rules,


payout, profit split, frequency,


all of that stuff. Um, of course, why it


matters. Um,


you know, I kind of did this with each


one. If the challenge is well defined,


you know where you stand, how much of


what you make you actually get and how


often, how strict the risk is, uh, free


resets, uh, reputation,


you know, reviews, and then as far as


like um maybe how it can fit into how


you might trade. Then I also try to


think of like red flags. You know, if


their rules are kind of vague, if they


kind of change their rules, um, you


know,


very tight draw down,


um, monthly fees, you know, repeated


payout, denials, complaints, uh, kind of


scam accusations.


So, that's kind of what I try to think


of with each one that I've done.


Uh so of course I stopped with um


started with Topstep. Um I know a lot of


us now have an account with Topstep. Um


so of course they're well known in


futures prop firm trading space. Uh you


go through a combine then once you pass


you get the express account. Um, you


know, so I just kind of did a brief


description.


Of course, pros, uh, they're well


established. Most people know that know


their name. Uh, I feel like their rules


were pretty clear. Uh, profit target 6%,


max loss 3%, end of day. Uh, they do


have the 50% consistency rule. Um, you


know, you have to close all trades by


4:10 Eastern time. Uh


I do think they also have a fast payout.


um from like the time I request it to


the time it hits my bank was you know a


le less than 48 hours but about you know


I think it took maybe


I don't know maybe 12 to 24 to like get


an email of like we've sent it and then


I had to wait for like you know um for


that to hit like my bank kind of to


connect so about one to two business


days uh Um, of course, after 5 days of


minimum $150 profit, you can withdraw


50% of those profits. And they use Wise,


you know, AC wire, international wire.


Um, I used Wise with them.


Uh, so didn't have any issues with that.


Uh, they do have flexible account sizes.


I so you know 50k for $49


100k 999


150k for $149 a month and then I just


kind of put you know each one what the


profit target max loss limit max you


know uh contracts that you can trade


with each account. Um and then of course


always keep an eye on your leverage but


with top step the system will reject the


trade if maybe you've you know gone over


some of this. Um they do have end of day


draw down which is nice. Okay. So they


just whenever you know market closes


that is what they kind of consider


um you know when your draw down kind of


is calculated.


Uh no limit on how long you can take to


pass it. Um, you know, of course, the


only thing is if you go past that


um date, you know, where your uh


subscription renewal, then you know,


you'll just pay that again. Um,


and you can reset two times in each


account if breached. uh whenever you do


that. So if you breach and then you


immediately reset it, your monthly


subscription will then renew on that


reset date. Uh you can copy up to five


accounts which is amazing. I easy to


learn. I thought it was um I think the


Xplatform is really easy to navigate. Um


and then of course onestep challenge.


Uh the cons, um of course you have a


$5,000 limit per payout. Uh fees,


reoccurring cost, of course you just,


you know, pay for the monthly evaluation


until you're funded. Um


strict rules, uh of course the tight


draw down. Um I mean it's pretty normal


I guess with any other one. Um, but you


know, just kind of make sure you know


all the those draw down rules. Um, like


most of them not regulated. Um, you


know, so you're just kind of trusting


them to


to do the right thing. Um,


this one should be number one,


especially like today. uh potential


platform technical issues, platform


glitches, lag, support delays. Uh


I know y'all have experienced that also,


but that's I definitely have experienced


all that. Um I do think they have good


customer service response time. Um you


know, like I said, through emails or


even if you know, you talk to them on


the phone. Uh, but of course it's always


a toss up on them making things right if


and when their system glitches and it


causes you to lose a trade or an


account. Um, and then no alerts. I mean,


that's not a big thing, but I love


alerts. So, um, I just thought I'd throw


that in there as a con. Um,


of course, uh, who it works best for.


Um,


I probably should add like if you, you


know, trade futures cuz obviously that's


what they are. But, um, but yeah, if


you're a disciplined, consistent,


comfort, comfortable trading to a prop


firm's rules. Um, if you know, have


patience, if you don't pass fast, you


just continue to pay the monthly


subscription fees. And of course, if you


like the safety of a prop firm that is


wellknown,


um, take profit trader. I will say out


of all of them, this is probably my


favorite. And I haven't been trading


them for that long. But, um, but I think


I've been trading them


long enough and mostly because I feel


like I've gone through the process. I've


gone through the the challenge uh


growing a buffer and getting payouts and


haven't had any issues with them at all.


My only thing at first with them was of


course that it was um with


uh Trading View


and


I did not like Trading View. I had to


like relearn how to like, okay, I got to


set a pending or I got to set a box. And


I hated that. But um but I think with me


doing the challenge and I was doing it


very slow because I was really wanting


to get comfortable at Trading View


again. But once I did that,


then I loved it. Um so of course it's a


futures focused prop firm. you know,


they advertise onestep funding path,


straightforward challenge structure.


You do have to trade minimum five


trading days. Uh they have the 50%


consistency, but so like on a 100,000


account, you have to grow it 6,000. So I


can't do 3,000 one day, 3,000 the next


day, and pass the challenge. You can't


do that. You have to trade a minimum of


5 days. So, you know, even if you go


ahead and kind of hit that profit uh


target goal, you still have to like at


least do one trade a day. So, um


just kind of take that in consideration.


But if you're kind of building it


slowly, you know, more than likely


you're going to be trading for 5 days


anyways. Um


you know, so that's probably not not


that big of a deal. Um,


real quick, yes, I will explain the 50%


consistency rule. So, basically, your


highest profitable day h cannot be more


than 50% of your total profits. So, um,


like for instance, on a $100,000


account, you grow it to 6,000


to meet that requirement. So 50% of that


of course is 3,000. So in one day for


instance I could not make a profit of


say $4,000


because that would be you know more than


50%


of the my total profits needed. Um so


that's why if I'm trying to pass fast um


I will go 3,000 a day. So, as long as I


am below that 50%.


Um, there's some of them that are that


have like 20% consistency or,


you know, they're kind of different.


That's where like my brain is like,


but 50% like I can do that in my head.


Um,


so of course they promote same day fast


payouts and I agree with that. Um they


support multiple platforms uh Ninja


Trader, Trade of Trading View. Um of


course I'm using Trading View via Trade


of um to do that.


Uh so of course pros uh clear rules


again profit target 6%.


uh while you're doing the challenge, it


is end of day draw down uh you know,


which is 3%, they update at 5:00 p.m.


Eastern. Uh so with Topstep, you have to


be out by 4:10 p.m. Eastern time every


day. Uh with uh take profit, you can


trade up until 400 p.m. You have to be


closed, which I'll get to that I think


in the cons, but you have to be closed


by 5:00 p.m. There's no uh you know,


they don't just close it for you. Like


Topep, if you accidentally leave one


open, you know, they just close it out


for you. You can't do that on here.


You'll breach your account. Um, of


course, a consistency rule 50%. Um,


you know, minimum trading days five. Um,


they have no daily loss limit. Uh, you


can withdraw daily once you have a


cushion. So, uh, on the $100,000


account, I had to grow it to $3,000,


which is my buffer, which then becomes


my draw down. So you have to grow it


whatever your draw down is for each


account


you know. So of course like down here


you can see 100,000 account uh $100,000


account is the uh the draw down is 3k.


So that is the cushion you have to grow


it to before you can withdraw. And you


know so of course 50,000 you have to


have a $2,000 cushion. Um, but then


anything over that 3,000 you can


withdraw daily. So if you come in and


you make $500 today, you can turn right


around and withdraw that. Um, and you


can do that every single day. Um, they


do have a 8020 split uh in the funded


account. Uh, and then of course now they


have Plaid, Wise, or PayPal. I use Plaid


on this one. Uh whenever I opened it,


they didn't offer the wise, but they do


now. So uh but I already have this set


up, so I just kind of kept it. Um in the


pro live account, uh if the live account


is breached, um then you are entitled to


the buffer funds.


So of course, the $100,000,


you know, you had to grow this $3,000


buffer. So if for any reason you breach


the account, you then can withdraw this


amount. They will give that to you. Um


but of course if you've had the account


under 60 days, you only get 50% of the


buffer. So say if I breach the account


and I'd only had the account, you know,


15 days, then I can withdraw $1,500.


uh if you have the account over 60 days,


you're entitled to 80% of your buffer


money. So, I thought that was really a


good pro. Uh that, you know, they're


kind of like, hey, you made this money,


like we're going to give you some of it


anyways. Um no limit on withdrawal


amount. Anything over your buffer you


can withdraw. um you know so if you grow


it to $10,000 you can withdraw $10,000


uh simplified path uh of course onestep


challenge


um good for future traders


um flexible platform support uh multiple


platforms of course gives you choice


with um you know trading view or


whatever


of course they have also have flexible


account sizes they have uh quite a few.


They have a 25,000 for 150 a month. So,


they're a little bit more expensive. Uh


50k for 170, 75


uh for 245,


100 for 330, and 100 for 360.


Um


I will put somewhere in here. Let me go


back up here. Um, I'm gonna put the the


promo code that they have. So, they have


no fee 40. Um, they kind of go back and


forth. It's always 40% off. Uh, but


whenever I did it, and I think they may


be doing it now, uh, but with this promo


code, it's 40% off. And then I think


they're also doing once you get funded,


you don't have to pay like the


activation fee. So it's kind of like top


where you have, you know, the $149


activation fee. Uh you do not have to


pay that and it is for life. Uh so you


can keep buying them and you that code


will always work for you even if like


they don't have it for everybody. Um, so


you know, it did make this a lot


cheaper. And then of course the no


activation fee once you pass that was


nice also. Um,


during your evaluation, you can trade


news, you know, like a lot of them. And


same you can copy up to trade uh to five


accounts. Um, and then the cons,


uh, the support responsiveness


can be slow. Um, and only so whenever I


first got mine, um,


I like would try to make a a trade and


it would say like it's a non-tradable


symbol or something and I could not


figure out why. So, I had to get with


their support and like figure out what


was going on. And I think if I remember


correctly, it was something with like


the CME data something, but they had to


fix it on their end. Uh, but it was a


little slow getting with them. Like I


was kind of getting frustrated. So, I


don't know if that was a


just a weird timing thing or what, but


um but I didn't want to put that like as


a con. Um and then of course once you


are funded, they have intraday draw


down. Uh so it trails your unrealized


profit in real time. So I you know it


doesn't like if you're in draw down and


you know it is trailing that. So, um I


have not had any issues with that, but


but that is a lot different than the end


of day, you know, because if you get


stopped out, you know, and then you make


it back before the end of the day, um


you know, obviously that is nice, but


the intraday it will trail you uh as you


go. Uh so just be aware of that. Um you


know of course it's the same it's a


monthly subscription during the


evaluation phase until you pass like


kind of like top step. Also once you are


funded there is the rule of no news


trading. So you can't have any open or


pending trades one minute before during


or after high impact news. Um, of course


you can always look at uh Forex Factory


uh but inside of your um dashboard on


take profit they have a calendar and it


will show and and include like impact


news this day. Um and then they also um


you know they have listed like what


um hold on give me just a second.


Okay. Um they also have included which


ones you can't. So of course FOMC


statements announcements


and they happen Wednesdays at 2:00 p.m.


Eastern. Uh non-farm payroll Fridays at


8:30. CPI. Uh if you trade oil, um you


know, you can't trade during the crude


oil inventories. Um I don't know if


anybody trades these, but if you do


trade the 10-year note or the 30-year


bond, you can't tra uh trade during the


bond auctions. Uh but you are allowed to


trade through the Fed speakers and FOMC


meeting minutes event. uh just not the


FOMC statement announcements, but uh for


me just because I would have to have


post-it notes everywhere, if I see a


high impact news folder, I just stay out


of it. Uh because I just don't want to


chance any of that. Um and of course um


you know confident want to minimize


valuation drag um you know if you prefer


fewer stages and if you want to withdraw


profits as often as you want without


waiting additional days each time. So um


of course we know with top step once you


withdraw you have to do another 5 days


at 150 days you know all of that you


have to kind of start over. So um you


know this one will work if you want to


withdraw


daily as you know as much as you want.


Um let me get a drink water.


So and then of course top one futures


um


they offer instant funding or


singlephase challenge.


So, of course, the instant funding, you


don't have to pass any challenges.


You're just kind of they instantly fund


you. Um, and then you just, you know,


have to kind of follow those rules. So,


um, they actually have pretty good


reviews. And I will say that even though


I know y'all probably all like flinched


whenever you saw this name, but I I


don't know if it's just if maybe they've


gotten better. I haven't been with their


other one in a while or if this is kind


of a little bit of a different I'm not


really sure but um I have not had any


issues with them and I actually like


them and they use Xplatform. So um you


know they had they do have good reviews.


Um so some pros of course they do have


the instant funding account offered so


you don't have to go through the


evaluation phase. Um they have the


option of pay out within 2 days. Of


course you have to meet like criteria.


Uh that one may even be like a an


upgrade option where you like pay extra.


Um I have um


oh I think I have not had any issues


like I was just saying with this one


compared to the 4x one. Um, of course,


simpler process, fewer steps, one-step


evaluation rather than multiple phases.


Um, you know, transparent communication,


uh, support seems responsive and of


course they use the X platform. Uh, some


cons. Um, of course with like the


instant funding, some of the rules are a


little bit stricter. Um,


I think I just put this in here because


we all know the name. They did have a


bad history. Um, with you do have to


trade for 10 days and meet the uh


consistency rule for a payout. Um, and


then once you get the payout, you have


to do that again. So, you know, you get


a payout, then you have to trade 10 more


days. Um,


and


I don't remember what I didn't put it in


here, but um,


Jill, do you remember real quick what


the consistency rule is? Is it 20?


>> Yeah, it's 20%. Okay. But but also what


what I told you what I didn't realize


until I went in and read the rules like


on the 50k the the first time you have


to make 6%. So, I didn't realize I


needed to get to 3,000 before


um I could get a payout. And I think


above I have to go above the 50 or


3,000. But then the second time it's


like 5%, you have to get 5% and then the


third time and then on it's like 4%.


>> Yeah, that's right.


>> But yeah, it is a 20% consistency rule.


>> Okay, I'm going to put that in there.


Okay. Um,


so again, you know who it's kind of


would be good for. I feel like it's a


good middle ground. It's simpler than


multi-phase, but you know, less risky


than, of course, newer firms. uh if you


want fewer steps. And I would I would


still like test small or of course just


try like one account at first, get a


payout and then kind of decide if you


want to add to it. Um okay, another one


is a Alpha Capital Group.


>> Um


>> this Wendy, sorry, just a second with


that last one. Um did you say what the


split was? I might have missed it


>> on this one. Top one.


>> Yeah.


>> Um,


no, I didn't. I will add that on there,


but um


I can't remember what it is right off


hand.


>> Okay, no worries. But yeah, and you said


you're going to make this into something


in in circle.


>> Yes, I will. Yeah, I would do it into a


um like a a word, you know, document or


whatever. Um that's not the word I'm


looking for, but I'll make one and then


I'll put it in circle. Uh but and I cuz


I realized there's a couple more things


I want to add on this. Uh but I will add


the profit split and then I think I also


want to add like the rules. I don't know


why where that went, but but I want to


add like what the rules are. Um so yeah,


that one will have more stuff to it.


>> Okay. Thank you.


>> You're welcome. Um okay, so alpha and


I'm also going to add um promo codes


that I think some of them are even still


having like I think the top one futures


I think I got an email that um they're


maybe having like 50% off right now. So,


next to the title, I will add promo


codes. And then I think maybe even Alpha


Capital might have one going on right


now, but I'll look for like the most


recent one. Um, okay. So, this one I


decided to try. It is a Forex prop firm.


So, I know not everybody in here has


kind of switched over to futures. Uh,


you're still, you know, kind of trading


forex. So I I did want to add, you know,


some of those in there as well. But


Alpha Capital Group, you do trade forex.


Um, you know, so


um,


you know, if you want to kind of just


trade forex, um, I used, uh, Trade


Locker. I think that was one thing that


kind of made me want to try them. Um, I


did see really good reviews, but I was


also at the time like probably having


like trade locker withdrawals and so it


kind of was able to let me get over


there and trade. Um,


so they have a step one, two, three, you


know, then funded. um no maximum trading


day limits but a minimum of three


trading days in each phase. Uh they have


a profit split of 8020 for a funded


account.


Uh their payout methods are you know


rise wise bank transfer. I used wise


with this just because I'd already had


it. Um, of course pros they use trade


locker, MT5, C trader, DX trade. I have


never messed around with these two, but


I have used MT5 and of course trade


locker. So I use trade locker with them.


Um, of course it's forex trading. Uh,


they have multiple evaluation modes


which gives you choices. So you can do a


one step, two step or three step. Uh one


step is 10% profit target, uh 4% daily


loss limit and 6% overall loss limit. A


step two-step,


it's a 6% profit target for step one and


then of course 6% for step two. you have


a 3% daily loss limit and a 6% overall


loss limit. Um, you can pay extra to


increase your percent. So, I think they


have like an option where if you want to


do like a daily loss limit of like 8% or


something like that, you can like pay


extra for that. Um,


a three-step is 8% target for the first


uh 4% for step two, 4% for step three,


and then of course, you know, same thing


8020 split once funded. You can hold


trades over the weekend on some


accounts. I think they have like the


option of um if you want to


um I think pick like the swing trading


option. I think you have to maybe pick


that whenever you first get your


account. Um,


and they they have pretty much the same


like they don't have as much options to


trade and I think a lot of almost every


single one of them are like the pro.


So if you remember whenever you're


trading the forex, you know, it was like


uh NAS.Pro or whatever, they have those.


But yeah, I was still able to trade, you


know, my NAS over there and all of that.


So, um I think all of the main major


ones you're able to trade. Um


so, of course, consu


any trade that you get into, you have to


be in it minimum of 2 minutes. So, you


can't just get in immediately, get right


back out. um can't trade news on some


phases uh 2 minutes before after and


then some are 5 minutes before after. So


make sure whichever one you choose you


kind of read the rules based on that


step that you chose cuz they are they do


vary. Um, and of course, same thing that


goes along with that, there is a lot of


rules, so be sure to read through all of


their objectives, the different rules


depending on which step, you know,


account you go with. Um, and then of


course who


who it's good for and of course what to


watch out for. Um,


y'all all know trading with Forex, you


have spread. So, just know that you're


going to have spread with this. Um, and


as always, go with, you know, maybe a


small one first. Test their with


withdrawal their rules. Make sure you're


really comfortable with them. Um, you


know, then if you like them, then


continue on. If you want to buy more


with them,


Fender Pro, um, out of


Let me get that out there. Um, out of


Forex


prop firms, Fun Pro was probably my


favorite. Um, and of course, it was the


same thing. I did use um,


Trading View or sorry, Trade Locker with


them. So, it is newer. um it's only been


around, you know, a year or so, but um


but I have not had any issue with it. Of


course, their Forex trading uh they


offer multiple challenges, one phase,


two phase, uh you know, they have the


you know, option of daily payouts after


you grow a 1% buffer. Um and then, you


know, or you can do just their classic


basic one. uh or you can also upgrade


for bi-weekly payouts. So they do have


like you know those options of like


adding you know paying extra for


different things. Um they do have daily


reward payouts.


uh you know if you qualify of course


once you're funded uh no hidden rules


support multiple platforms MT5


C trader uh you know for non US


residents and then of course trade


locker uh their profit profit split is


usually 8020


change this


so 8020 uh but of course with um add-on


options you can do up to 90%


um payout methods I used Rise uh but


they also have this USDC crypto uh


option. Um


they advertise unlimited time no


expiration on challenges as long as you


stay active.


Let's see. And then of course some of


their pros


as an one of their add-ons they offer.


You can get your first reward in 7 days,


90-day split, no minimum trading days,


and of course swing account. Uh they do


have a scaling plan which is was kind of


the big I guess selling point with


Thunder Pro. Um so if once you achieve a


10% profit target um each trading month


for three consecutive months and uh your


account they will increase your account


by 50%. And then of course you can


repeat that process over and over and


the scaling continues up to 5 million.


So, uh, that's a pretty crazy scaling,


you know, uh, thing that they offer. Uh,


so this was like kind of a big thing


with Fender Pro, why a lot of people


love them. Um, you know, because that is


a pretty good offer. um flexible


structure uh multiple challenge styles


to match your pref preference because


sorry because of course they do have the


option of uh swing trading. So you know


you can get on some of those higher time


frames um and hold trades for multiple


days. Uh challenge cost is refunded


after first pro uh payout.


Um,


same roughly a 48 hour payout process.


Um, I felt like they were pretty


transparent. Um, I did make sure on the


one that I picked that I really read


through their rules and I will even, you


know, cuz initially whenever you're


looking at them, it'll just have like


the little list of like profit target,


max loss limit, you know, their rules.


But I even go a step further and I go


into their, you know, their like


question like their FNQ section and I


will read through almost all of those


cuz I feel like there's always something


that I learn from there that wasn't on


like say like their homepage with their


rules. So just make sure you like really


read through all of that stuff. Um,


okay, let's see, where was I? Um, of


course, lower starting evaluation fee


compared to some of the bigger firms.


Uh, so for, you know, 5,000, you can get


it for, you know, about $70. And of


course, it's refunded after your first


payout. Um, and I felt like they had


good instrument range to choose from.


Uh, cons, like you know, most, they're


not regulated.


um you know some traders there is higher


spread during certain sessions London


Asian you know all those um I didn't


really trade those so but this was you


know mentioned quite a bit


you do have to buy the challenge with


crypto


so you know if we any of y'all were kind


of funding live accounts or getting you


know maybe other prop firms terms you


kind of remember you had to buy it going


through Bitcoin or something. So you do


have to buy it with crypto. Uh and then


of course there is a consistency rule


with some of the phases. So again


whichever phase you go with make sure


you read all the rules. Um good option


if you want a more modern flexible prop


firm. uh if you're a discipline, you


know, less risky, try some challenges


with them. Um their structure, you know,


I felt like it gave room to like test


the waters without being like locked


into multiple phase systems.


Um and then of course I just did a quick


like side by side on


all of them, basically like a summary.


Um so of course you know I did the firm


top step take profit uh strengths why I


used them uh the biggest risk drawbacks


with each one um and then you know


who like if you prefer to use the X


platform you know kind of who it's best


used for. Um, and then of course my


kind of one through five of who I who I


prefer. I take profit trader my number


one. I feel like they have the best


payout. Um, you know, just option


because you can do it daily. I like


that. Um


I don't want to say that I don't trust


prop firms but um but I I am careful


with them. So uh the fact that if I make


my money and I want to withdraw it, I


love the option that they allow me to do


it daily. Um so that may be a big reason


why they're number one to me. But a I do


think they have the best payout.


um you know uses Trading View via Trade


Evate and I feel like their rules are


pretty easy to follow. They are pretty


strict uh but I think they're


transparent enough that they're easy to


follow.


Uh number two, Fun Pro. Uh they're my


favorite for Forex trading, of course. I


love that they use Trade Locker. Uh, and


I love that they had the scaling plan.


Um, my third choice would be Top One


Futures. Uh, probably because I love the


Xplatform. You know, I've gotten used to


that, so I really like it. Um, and then


of course they do have the instant


funding option and I feel like they had,


you know, quick payouts. Uh, Topstep. I


love that they use the X platform and


they have quick payout. Um, and then of


course Alpha Capital Group, uh, you


know, Forex trading if I were to trade


that. Um, you know, but they do use


Trade Locker, which I like. And again,


quick payout. I feel like every single


one of them uh was about the same time


frame with their payouts from the time I


requested to the time it hit my bank


account. They were all like I would say


within a few hours. So I did I did like


that. I haven't had any issues with any


payouts from these five right here. Um


so and of course my suggestion is pick


two or three firms from you know if you


are going to use this list um and for


each one that you kind of pick uh read


all of the rules line by line even go


into their F and Q read make sure you


read everything. um you know, maybe even


write it down if you want to take


screenshots, however you want to do it.


Uh but make sure that


you have them like in front of you until


you've done it enough to where you just


kind of know them. You know, of course,


like me, I have challenges with


different ones and they do have


different rules.


So, I had to do that. I had to write


down everything until I knew, okay, this


one I can trade news. This one I can't.


I need to be out of this one, but I need


to be in this one. So, just make sure


you know every single rule.


Um, and of course along with that, know


exactly what will breach you. um and how


strict they are because of course like


with top step if I'm not closed forget


that I'm in a trade which usually


doesn't happen but if for some reason


that 310 mark hits and I'm still in a


trade they just close it out you know I


don't get breached for it uh with top


step if I were still in a trade at 4:00


on the dot when it changes and market


closes


they would breach my account. So, make


sure you know how strict each one is, if


it would give you a soft breach,


not even a soft breach, they don't do


anything, they just close it out for


you, or if it will breach you. Make sure


you really understand


every single rule. Um, and then of


course, if you know, maybe if you're new


to prop firms, uh, or just kind of want


to test something out, start with the


smallest one. So, if you lose it or


breach it, you're only out, you know,


whatever the lowest one cost, $50 or


whatever.


Um, and if and when you're funded, do a


small payout test as soon as you can. uh


you know and even if you don't want to


take all of it and you want to just try


a small dollar amount um you know at


least try that as soon as possible to


make sure that you don't have any issues


or even if there's an issue with your


bank and wise you know or whatever you


just can kind of get that get that


figured out


um you know definitely keep logs um and


I probably only say this because of um


top step or yes top step. Um you know


luckily you know the dashboard will keep


some of those logs as far as um you know


like the time you entered the trade,


exited all of that. But um like I said,


a lot of times if you don't have a video


or something to give them, you know, may


not get it fixed. Um


and of course after you pass one, you


can kind of go back and re-evaluate


before maybe trying to go for a 50,000


or 100,000. You know, just kind of


re-evaluate what you thought of it.


mindset, all of that stuff. Um, always


have a backup plan. Um, prop firm you're


comfortable moving to if the new one,


you know, starts maybe acting shady. So,


um, and then of course before, you know,


fund live accounts with some of your


payout if you can to slowly grow a live


account and not fully rely on prop


firms. Um, I say that I don't have a


live account yet. If you're on the, you


know, live call this morning, kind of


talked about that. Um, only because I'm


still trying to decide


which one I want to go with. But,


uh,


you do want to eventually do this. Um,


you know, or have, you know, a separate


bank account where you, you know, you


don't spend it. just kind of you want to


keep it to compound it some way. Um


yeah, so those are the ones that I have


tried that of course I felt like I would


recommend to you guys. Um but I will go


in and add


there's a couple of things I I want to


add to the top one one and then um and


then I'm also going to add the promo


codes. So that way if you guys do want


to try any of these um you can use the


promo codes that are going on right now.


And some of them are really good. Like


of course I said the uh top one email


was like I think 50% off and then you


know some of them will have where you


don't have to pay the activation fee or


something like that. So, um yeah, I


think that's really um some good promo


codes that are going on. But yeah, so


I'll fix some of this up. Um I'll create


a document, whatever it's called, and


then upload it into Circle. So, okay,


I'm going to stop sharing my screen. And


um I know we don't have much time, but


um


give me just a second.


And I want to um


maybe call on somebody.


I was going to check my participants


number and see if it just dropped by


80%.


Um,


okay. Let me Sorry, I made like notes of


of that. I just got to find it really


quick.


Okay. Going to do a quick check on who's


in here. See if they're even in here.


Okay. So, I think one that


uh we have noticed has, you know, really


been kind of posting a lot. Um,


Lisa Gettis,


sorry if I said your last name wrong.


Are you are you like where you can share


your screen?


>> Yeah. One sec.


>> I just got to close my


>> um I was gonna say, hold on. Let me I


think I got to make you


a co-host.


I'm not in anything right now, just so


you know.


>> Okay. And that's fine.


>> Okay.


>> Yeah. So, if you just kind of want to,


you know, maybe just pull up a chart and


just kind of show like what your


confluences are and, you know, maybe


just like if it does, you know, this I


would look into maybe getting into a


trade, you know, or something like that.


>> Okay.


I'm a little nervous. Okay. So,


>> it's okay. Is it showing?


>> It is. I can see your screen. Can


everybody else?


>> So, I just opened a new account with


Take Profit Trader.


So, yeah, right here I'd be waiting for


a strong rejection off my 4 hour


and then


an M and then a cross of my EMAs.


I have a lower low, but this is just so


messy for me. I wouldn't take this. Um,


and then I'd probably aim down for the


15 minute because of this FPG that I


have marked out from


the one hour.


Yeah. So, that's And then I'd probably


aim my TP at the top of this.


Does that make sense? Did I ask?


>> He does. Yeah, I love it. Yeah, I think


all of that is is great. Yeah, I love


that. You know, of course, like you


said, you would wait for it to react off


that 4 hour and see what it's doing. And


I agree with you, the way it's like


ranging in there.


>> It's like, okay, it's really testing


like that price like that's a strong,


you know, resistance area. So, um, yeah,


I think all that's great. Yeah, I think


like you said, wait for, you know, maybe


that break is structure and I would do


the exact same thing as you, you know,


put my my TP at that 15minute resistance


and of course around that FEG, I would


watch it as well. So, I thought that was


awesome. Good job.


>> Thank you.


>> Yeah, you're welcome. Thank you for


doing that.


I'm so surprised that that works. I


thought top step was down. Is it just


some people's?


>> I think trade of eight.


>> Yeah, she's on trade of


>> Oh, gotcha.


>> Yeah.


>> Bummer. Okay.


>> Yeah, because that's what I'm in trade


of eight also and it's working and I So,


yeah, it must just be like the X thing


that's going wrong.


Okay. Gotcha.


>> Yeah. Okay. So, let me um which I don't


think I need to share my screen, but um


yeah. So, I won't worry about doing any


of that cuz I think me uh


There we go. Okay. Yeah. So, do you guys


have any questions with u any prop


firms? you know, if there was something


that maybe you were uh curious about


that I didn't have on that list, let me


know and I can, you know, add that


before I upload it into Circle. But, um,


but yeah, does anybody have any


questions regarding


>> I just mentioned one mistake I made this


morning with my new account?


>> Yeah, go ahead.


I use those buttons in the top left, the


buy and sell,


and it doesn't let you move a stop loss


or take profit if you use those. So,


just fair warning to everyone.


>> It is. Yeah. And I think that's why I've


gotten in the habit of setting the


pending


because I want to, you know, not go in


at market because I noticed the same


thing at first. Um, and I think because


Melissa always used Trading View. She


loves Trading View. And I would just go


in at market and I'm like, "How do I set


a stop loss and a take profit?" She's


like, "Well, you can't unless you do


like the box, you know, or the right


click and pending thing." And uh yeah,


so I've just gotten in the habit of


setting the pendings uh just so I can


see where that stop loss and take


profit. But yeah, that's a good thing to


bring up cuz that is obviously huge. You


know, you want to do that or have the


ability to do that.


Um okay, so do you trade multiple props


from different firms at the same time? I


do. Yeah. So, sometimes it is a little


bit crazy, but I kind of try to and I


like sometimes won't get into the same


trade


on exactly all of them, but like I'll


have one like open on my laptop and then


I'll have like one on this screen over


here and then I'm like also looking at


my phone. So, I'll have them open on


different things at first, and I just


kind of do the same thing if I'm


entering in or setting pendings. Um, I


just make sure that my stop losses and


my take profits are the same area. So,


sometimes my entries may be a little


off, you know, depend on if I'm like


switching. Um, but I know that I know


where each stop-loss and take profit is.


Um, but yeah, I do that. It It's


probably not good for my brain, but I


don't know. Maybe it's maybe it's making


me younger. Who knows? Cuz I it really


has to do a lot of like


work for a few seconds while I'm setting


them all. But, um,


>> she was talking about the stop. She


should be able to go over to the DOM and


then do stop, you know, limit.


>> Uh yeah, you can. But on some of them,


um if you like it's different with like


some of them um if you just go into


market, it it won't let you uh set a


stop-loss once you are in the trade. So,


it just depends on which prop firm


you're, you know, which one you're in.


But most of them you you can do that.


Some of them you can't.


>> So, you got you got to definitely make


sure you're aware of if you can or can't


do that.


Yeah, exactly. Making me younger.


Hey, so I got a quick question. Um,


>> yeah, go ahead, Wendy.


>> So,


since you're making regular money at


this and doing withdrawals from


different ones, have you set up like an


LLC that you're doing all of this


through that you're, you know, you're


doing it as a business or are you doing


it just I'm just thinking kind trying to


kind of think ahead tax purposes with


things. um you know if there's any write


offs that you're doing because of


equipment that you've upgraded, things


like that.


>> Um yeah, so I am a I do a lot of uh


things for write offs um you know


basically as much as I can like even if


I buy a challenge and and it breaches


you can write that off. So, you can kind


of offset uh if you've passed a


challenge, take profits, but if you've


maybe lost accounts, you can offset some


of it that way. Um I, you know, of


course, write off my equipment, my


Wi-Fi, um office stuff. So, there's like


a portion of like electricity,


um you know, all kinds of stuff. So, um,


of course I had like an old massage


business and one of my close clients was


an accountant. So, he kind of told me


like every little thing you can write


off. Um, so I, you know, if I go to


Walmart and I buy pins, like I keep that


receipt and like I will write off


everything. Um, so and of course I have


like with my SLS,


it is a um it's an LLC. Uh, so I'm going


to see how I can maybe intertwine those


with it, you know, with it kind of it's


like my name basically I'm like with me


being the owner. So this year I'm going


to see how that can kind of intertwine.


Um but yeah, just keep track of,


you know, definitely if you have bought


prop firms and you breached them, you


know, but just keep track of each time


you paid and you bought for a prop firm.


Uh because you can offset that a little


bit. But um but as far as the LLC, you


know, that's mostly just like insurance


liability,


um I know if you get to like a certain


point, uh like with my old business, I


had an escorp,


uh which allows you to write off a lot


more, but there is a in Oklahoma


anyways, um you know, you have to be


able or


um I don't think it's a requirement but


it's a suggestion that you know you


don't really need an escorp unless you


are at this level you know you make this


much in a year um you know then you can


do that to write off a lot more things


but if you don't make this much in a


year the fees that you have to pay to


become an escorp are kind of a lot they


are more than what you make. So they


kind of say like you you don't need to


do that unless you are making over a


certain amount you know in a year. Um so


there is there's different things I


guess I'm sure depending on what state


you're in. Um of course for me I always


set back about 40%. Uh, usually it's


more around like the 30%


mark on taxes, but um, but I always just


do 40 just to like be safe. Um,


so yeah, it's probably different for


every state, but that's just kind of


things that I write off and um, you


know, keep track of. So, but yeah, every


single thing that I can think of that,


you know, my phone bill, uh, because I


trade on my phone, I work through my


phone. So, anything that I can think of,


um, you know, laundry soap because I


have to wear clothes during the call.


Like, I mean, I will try to think of


literally everything. And um and I will


always do like a um Excel spreadsheet


and I'll kind of go ahead and separate


it all.


Pretty much I probably do a lot of the


work for the accountant, but I'm like,


"You ain't going to miss it because I'm


going to write down for you." But um and


then I leave it to them to be the


professional and be like, "Come on,


Shay. You are not writing off dog food


for your business." So like then I leave


it to them to like exit off for me and


and make me legal. So but yeah just just


try to think of you know


for your write offs anything that you


are using


that you can think of you know for


trading and and write it off. You know


you can at least write off a portion of


it. May not be much but um


>> but that's pretty That's for your


business, not capital gains tax on what


you make.


>> Well, you have to have a business.


>> Well, and it depends on if you if you


get to the point to where you can turn


it into your business, which I think is


kind of what, you know, maybe Wendy was


talking about if you get to that point


to where you're, you know, making


withdrawals and turning it into like an


LLC and a business. it.


>> No, but in theory though,


you got to be careful with that because


the SEC could consider you a


professional


>> and then you then you then you'd have to


pay for real time data


>> because they definitely want to like


just


>> they already did that to me. They sent


me


>> they'll send me a letter.


>> Yeah. do your due dil diligence and


check in your state for sure. Um, you


know, I'm just giving my personal what


I've done. Uh, it doesn't mean it's


going to work for everybody. So, make


sure in your state, wherever you live,


check the rules. Go talk to an


accountant. Uh, but I will say make sure


you check with an accountant that


preferably has dealt with somebody uh


that has that has, you know, turned in


things for day trading. Uh, the one that


I went to, she has clients that, you


know, have done day trading. Uh, which


is why I kind of stuck with her. So, um


that is probably a good pro thing that I


would watch for is um somebody that has


experience because they'll they'll kind


of already know all of the rules uh that


you'll need to abide by. Um and maybe


just give you pointers, you know, of how


to do it, you know, whether it's


quarterly. Um, you know, at first we


checked in quarterly and I kind of, you


know, brought in my, you know, my gains,


my losses, and she kind of based on that


like, okay, quarterly plan on paying in


this much based on like this much


profit. um you know so you can do that


with an accountant and to where you're


not waiting 12 months and then finding


out like what you owe you know you can


do it quarterly and you know kind of


give you a better idea like okay if I


make 10,000 in a month I need to be sure


to put back this much. Um, but yeah, I


would just kind of check, you know,


around your area for an accountant,


preferably one that has dealt with


somebody that day trades. So, um,


>> thank you.


>> Do the prop that was very helpful.


>> Okay.


>> Do the prop firms give you 1099s?


>> Yeah. So, a lot of them whenever you go


to do the payout, um, you'll have to


fill out like tax stuff and then you


>> at the end of the year.


>> Yeah. Yep. A lot of them will send you


the 1099.


>> That's a lot easier than trying to keep


track of


>> Oh, yeah. Yeah, for sure. cuz I know


like with um with top one, you know,


whenever we had those a year or two ago,


um I was printing off the like they had


that section where it showed every


single trade that you took. That's what


I was like printing off and it was a


lot, you know, cuz I mean as a scalper


like you can imagine how many trades


that was. Uh but yeah, so the $1099 is


definitely, you know, you you still want


to kind of keep track of everything, but


um


but yeah, it is kind of easier to keep


track of. All right, guys. Well, I will


fix uh that word document and get that


uploaded into Circle. Um I'll try to get


it uploaded today, but um but if not,


I'll definitely get it uploaded


tomorrow. So, um, yeah, and if you think


of any other questions,


post them in circle in like the prop


firm area and I'll make sure to add that


on there. So, um, all right, guys. Well,


I will see you guys on tonight's live if


you join um 700 p.m. Central time. And


we'll see what the markets are doing and


see if Topstep Xplatform


gets their crap together today. All


right, guys. You all have a good day.


All right, bye. See you.$video_21_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_21_summary$Shea lays out the trade-offs of using prop firms, including the upside, the restrictions, and the pressure they can create. The goal is to help you decide whether they fit your current stage as a trader.$video_21_summary$
      ELSE summary
    END
WHERE sort_order = 21
  AND title = $title_21$Prop Firms: Pros & Cons$title_21$;

-- Backfill watch-page content for lesson 22: Eliminate Burnout
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_22_transcript$Hey, so today's call is going to be a


little bit different. Um, but I've


noticed in just kind of the chats and


all that they I've seen a lot of talk


about, you know, just getting in the


charts and not being able to get off of


the charts and almost that kind of um


screen addiction that I know can happen


with trading. uh for when I uh I mean I


even sometimes still do that but I know


in the like beginning whenever I started


scalping


it was like really bad to where I felt


like I was you know in the charts


all day long and even if I wasn't like


taking any trades


I was just staring at the charts and you


know I know a lot of it can be from if


you feel like you're not looking at the


charts or setting trades that you're


kind of like falling behind or not doing


necessarily, you know, what you should


be doing or you're missing out on trades


and, you know, it actually can do the


opposite. It can like burn you out


really quickly. And you know, I've even


seen a little bit of that going on,


you know, to where, you know, either


it's bringing up a lot of anxiety and


stress. Um, you know, or you're just


kind of getting to the point to where


it's like, I don't even know if I want


to do this anymore. Like, I'm just so


sick of it. Um, you know, and you want


to make sure that you're not getting


that chart fatigue. Um, so I just kind


of want to go over some different things


that maybe have kind of helped me uh get


over that. Of course, y'all know a big


one for me is alerts. Um,


so um, you know, of course, most blown


accounts don't come from bad analysis.


They come from either boredom, revenge


trading, um, you know, overconfidence to


where, you know, maybe you're not seeing


your confluences line up. um


you know so


I want y'all to if you haven't already


started like making journal entries uh


whether it's on your chart in a notebook


on your screen wherever you want to just


kind of um journal throughout the day.


Um but um you know of course ask


yourself how long are you watching the


charts versus how often are you taking


high quality entries? Um you know signs


of chart fatigue if you're taking setups


you wouldn't teach somebody. So if you


were showing your children, your


neighbor, whoever it might be, if you


were sitting down to show them how to


set a trade, um if you would not teach


them


and you know particular entry to get


into, then um you know, then you're


almost like forcing the trades. So, uh,


if you're taking setups that you


wouldn't teach somebody else, um, to


take, uh, you've made money and then


couldn't walk away. So you know whether


you made money, secured the profits and


then kept setting trades and of course


we all know a lot of times whenever you


do that by the end of the day you've


given


some if not all of it back and even end


up being negative um you know by the end


of the trading day. Um, and then of


course if you're entering trades just to


feel productive, I feel like, you know,


you need to be setting trades. Um, I


need to be doing something. You know,


I've gone all morning without trading or


especially if you take a day or two off


of trading. you know, you almost feel


like you have to play that um that


catchup and you know, you just don't


want to uh do that because you'll end up


forcing trades. Um, of course, set


alerts at key zones. Uh, you know,


whether I set them at a FEG or if it's


getting near a support and resistance


area, a area of even of hesitation, if


it's like a caution, you know, line that


I have marked up. um I will set alerts


at those places and that way won't even


look at the charts until those alerts go


off and then um you know then I will


open up the chart and reassess it at


that point if I want to get in the trade


kind of check for all the confluences


um also uh maybe make a three strike


rule if you don't see at least minimum


three of you know whatever your


confluences are but clean confluences


then walk away and you know set your


alerts come back and you know only open


up the charts and look if your alerts go


off. Um if your alerts go off don't go


off then you know more than likely it's


either still consolidating


or you know or it's maybe like in


between say a 4hour you know resistance


and your 15 minute or 1 hour or


something but you know it's somewhere in


the middle uh to where you know if one


of your confluences is I will only set a


trade if it reacts off of a support or


resistance line. Um, you know, then you


know that if your alert didn't go off,


then it's not at that area yet. And you


don't even need to be looking at it


because you wouldn't have taken it


anyways. You know, if you had like those


set as your definite rules of


I will not set a trade unless these


confluences are there. Um, you know,


another thing is whatever your


confluences are, I think a lot of you


already do this, but put them on your


chart. You know, make it to where you


always see it with whatever pair you're


trading,


you know, pairs if you've gone to


multiple ones. Uh, but have them on


every one of your charts that you trade.


That way it's just it's right there to


remind you, you know, even a checklist.


Um, you know, I will not get in a trade


unless I have at least three confluences


telling me, you know, that it's a good


trade.


Um, and of course, you know, the goal


for all of us is to make the money and


keep the money. So, um, don't, you know,


don't give back the profits. Um, a lot


of times whenever you do that, it's it


may be because you're not setting a


high, you know, quality trade. Uh, but


most of the time it's because you're


setting a, you know, low quality trade


because of some emotion. I so you know


going back to whether it's your you know


your board it's a revenge a revenge


trade you know you're kind of forcing


the setup um you might see people


posting in circle that you know just got


a one one to two on NAS gold whatever it


might be and you know you open up the


charts and back to the FOMO that you


know we always talk about and you feel


like I need to get in this right now. I


missed that initial surge. Uh but you


know, you may not even take five minutes


to like check your confluences and you


know, it may be that you only have one


confluence and you just set the trade


because you feel like you just need to


get in the trade. um you know and


because you've like missed out of that


you know initial jump. So um you know


just set your alerts. Um


you know even if you maybe decide that


you aren't trading for the day


just don't look in circle. Um, you know,


if you feel like you're noticing that


whenever you see others are posting


about their wins, uh, that you have a


really hard time not jumping in. Um, you


know, if you kind of find that you're


doing that a lot of times, then maybe


set the rule for yourself that you just,


you know, you don't even get in circle


if you decide to not trade that day. Um,


and just kind of build that


that muscle memory of, you know,


confluences


have to be there for me to set a trade.


If not then I won't trade it. And then


once you kind of create that discipline


in yourself


you know then you can of course get in


circle and it just not bother you. Um


you know if you realize that you missed


out on some trades um you know and and


just remember like one good quality


trade a day. Even if you just take one


trade a day, but it said, you know, it


everything lines up with your


confluences


and you know, you maybe set a one to one


or maybe if you're going from a, you


know, area of resistance to the next


area, wherever your take profit,


whatever it might look like. But if you


take one good quality trade a day, I I


mean it can add up. And of course we all


know with a lot of us copy trading


you know into multiple accounts


a lot of times if you you know take that


profit which you may not feel like is


that much but you multiply it by you


know three four five however many trades


you know you may or accounts you may be


copying then I mean that can really add


up over time. um you know and especially


if you compare it to maybe what you make


in a day at your regular job. Um you


know for 8 hours you maybe make I don't


even know $2 $300. Um but if you take


one quality trade that you may be in for


30 minutes and it's $200. You know, it's


funny how that's not enough to us. And


um so always try to like bring it back


into perspective for you if you ever


start kind of, you know, questioning


that's not enough. I need to make, you


know, get into another trade. I, you


know, cuz I only made $250 on that


trade, you know, for that day. But, you


know, if you do that two, three times a


week, I mean, that's a pretty good, you


know, little bonus that can help you.


Um, so, you know, just kind of remember


one good quality trade a day can really


make a big difference uh in your account


by the end of the week, the end of the


month. Um and then on the flip side, um


even five random


emotional trades,


uh they can do the same thing,


you know, for your account for the


negative. Um you know, or bring it into


the negative.


um you know if they either weren't


really good setups, if you should have


been trading in the first place, whether


you you know were feeling a little bit


stressed or uh just you know your


emotions


aren't where they should be to be even


looking at the charts. than um you know


somebody that might take five bad ones


at the end of the week. You know your


one quality setup of just a small


profit.


A lot of times you'll end up ahead of


them you know in the long run. So, um,


so don't ever feel like or of course


compare, um, you know, if you see other


wins and things like that. Just, you


know, don't compare to whatever else.


Just set whatever your daily goal is and


make that a pretty, you know, hard rule


for you that once you hit it, you're


done for the day. Um, you know, of


course, every trade after the win has a


cost. So um you know once you maybe hit


a takerit or you just take profit


however you know that may work out um


you know every trade that you decide to


take after that uh you know start kind


of journaling what that is costing you.


Um whether it be just of course monetary


cost um you end up maybe giving the


money back of what you just secured on a


trade earlier.


You know, maybe it's just the energy.


You know, you feel just drained and


tired. Maybe you've been sitting at the


charts most of the morning and didn't


take a trade until maybe power hour and


you know so that put you sitting at the


charts from possibly you know say 8:00


a.m. if you got in with New York open


and you're not setting a trade until 1 2


o'clock in the afternoon. That's a busy


long day for um


you know just sitting on the charts and


you will feel that fatigue and of course


by the time you actually take your first


trade of the day you may be so tired


that


you know you I don't know you might not


even be seeing the charts with fresh


eyes.


maybe your confluences aren't there. It


just kind of all snowballs into,


you know, taking emotional trades. So,


um you know, that's where you need to


just kind of set rules and put them on


your chart. Um another one is, you know,


of course, your daily rule. Um you know,


you could do a oneand done. You know,


one quality trade a day and then I'm


done. and um


you know don't even look at the charts


after that. Or if you you know decide


you you know maybe y'all take uh two or


three trades a day and that is your hard


rule. Uh but on every trade after


a winning one. So if you hit take profit


any trade that maybe you decide to take


after that of course they still need to


be your you know high quality all of


your confluences still need to be there


but after that maybe you decide that you


will trail you know your stop loss uh on


your second and third trade. um you know


so of course if your first trade was a a


was solid high quality and hit take


profit um


you know well that's just what I just


said but but yeah maybe you know decide


to trail any other ones after you've


already hit take profit um or just be


done. There's nothing wrong with taking


one trade a day and being done. Um, and


then of course like journal entries that


I think would really benefit you guys uh


to just almost keep track of daily uh


with every single trade that you take.


Um, you know, write down how many


minutes uh do I sit watching price with


no valid setup. And you know, if you see


that I start watching the charts at 8:00


a.m., I may not take any trades until


either 9:00 a.m., you know, depending on


what New York open does, or maybe you're


not taking trades until the afternoon,


power hour or something. Um, but keep


track of all of that and you may end up


discovering that,


you know, I don't need to start looking


at the charts this early because I've


noticed that with the pair that I trade,


I don't, you know, maybe even take any


trades until um, you know, the afternoon


or something. So, you know, maybe switch


it to where, you know, you can still


wake up in the morning, but instead of


watching the charts, you know, you just


maybe readjust your lines and then set


alerts and, you know, again, don't look


at them until your alerts go off.


But then, if you feel like you really


want to sit down and study the charts


and actually watch them, you don't do it


until the afternoon.


you know, if you kind of have noticed


that you're, you know, not setting any


trades until a certain time of day. So,


you know, just kind of keep keep a


journal entry and, you know, see if


there's any kind of pattern that kind of


starts emerging with, you know, when you


sit down to watch them, when you're


actually taking the trades, what time it


is. Um and then um also keep track of


you know what is your perfect setup


checklist. Um you know again I was


saying just keep it on your chart. Keep


it on a post-it note somewhere near your


computer.


um you know to where you will not set a


trade unless every single one of your


you know perfect setup checklist gets


marked off. Um also what emotions do I


feel after my first win of the day? So


if you take a trade and it hits take


profit,


what emotions are you feeling when that


happens? um you know are you able to


just


sit in that excitement and be satisfied?


Um are you not satisfied? Do you feel


once you hit that takerit, you know, do


you feel that regret of um dang it I


said a one one look this would have gone


up to a one to two or it would have gone


all the way up to you know the next area


of resistance. Um you know what emotions


do you feel immediately after you hit


that take profit? Um, and if you feel


like you are a lot of times feeling that


um, I don't want to say regret, but um,


but it almost immediately


turns into that FOMO of well, I could


have gotten then


a very good sign that you just need to


walk away. Um, you know, because you're


you're already throwing in a kind of a


negative emotion with a win, which


we know there shouldn't be any negative


emotions whenever you just hit take


profit. But if you've noticed that you


are kind of immediately feeling that,


then, you know, either stay out of the


charts for the rest of the day. I you


know definitely immediately don't get


into another trade uh until that feeling


goes away because that could easily lead


to forcing trades. Um so yeah, just keep


track of it.


You know, if you're feeling uh content,


hit take profit. I don't have to take


another trade for the rest of the day


and I would be okay with that. I don't


feel like I need to look at the charts


anymore. Um, you know, or I can look at


the chart because I'm just, I don't


know, curious. but you don't uh have


that, you know, that kind of pull to


immediately set another trade even if


you see your setup, you know, kind of


all lining up. Um,


you know, and just kind of monitor


your emotions


with your winning trades.


um


you know cuz I bet if you went back and


kind of um


you know try to remember like your


emotions and you end up giving a lot of


it back. um you'd probably be surprised


what emotions cause you


to immediately get back in another trade


and of course a lot of times end up


giving those profits back. Um also um


add how will I know it's time to stop


trading for the day? So go ahead and


kind of uh try to think of something


before you're in a trade. So whether you


you know decide


I don't know once I am


um


maybe starting to slowly make decisions


of okay instead of four of my


confluences being there


um maybe if I only see two of my


confluences and I'm trying to talk


myself into that it's okay to get into


this trade. um maybe because you saw


somebody else post that they're doing


really well in that trade.


You know, if I start seeing myself do


that, that's you know, how I know it's


maybe time to stop trading for the day.


So, you know, whatever that might look


like. Um decide that ahead of time. That


way you're of course not in a trade. And


I know how we all can get, you know, we


will try to gaslight ourselves into


thinking, well, I mean, I know I would


have, you know, I said this, but but it


looks really good right now. So have


that rule already planned out before you


even get into the trade. And you know


then once you start recognizing


that you are doing whatever you know


whatever this might be um then you're


just done for the day you know don't


look at the charts uh don't do anything


for the rest of that day and just let


your let yourself just kind of reset


your emotions


and um


you know and you'll notice is a huge


huge difference whenever you go back to


the charts. Uh for one, how much easier


you're able to stick with your rules and


it not be able to um you know like you


won't be able to talk yourself into


getting into a trade, going against your


rules, forcing a trade. Um, if you just


kind of step away from the charts and


then come back,


then it just won't seem as appealing.


You know, it's like, I'm okay not


setting that. You know, I'll set my


alerts. I'm good walking away and it


won't affect me at all. Um, and of


course, me personally, I don't trade


every day of the week. Um, it may vary


on what day I don't trade. Uh, sometimes


it, you know, can depend on what maybe


like high impact news is going on. Um,


sometimes if there's too much news going


on, I will just decide to not trade that


day. Um, and sometimes if I'm in my


office, I will still watch the pair just


to see how it reacts. Um, you know,


maybe with my support and resistance


lines or maybe if I have an FEG marked


off. Um,


you know, it's still interesting to me


how it may react, but I'm okay watching


it and not setting a single trade. Um,


so you know, maybe even have that rule


for yourself that I only want to trade


three days a week. You know, Monday,


Wednesday, Friday,


uh, you know, maybe Monday, Tuesday,


Wednesday, and then the rest of the


week, you know, let yourself kind of um


just have a break from the charts, go do


something else, anything else.


um you know but just set that rule for


yourself especially if you feel like


you've noticed yourself you know


Sunday evening when market opens back up


you're in the charts and you know Monday


through Friday you are in the charts


whether it is all day long um you know


or you just feel like you have to set at


least one trade a day or


you know or you're just failing at


trading. Um you know I I promise you if


you just take


time away from the charts


um


you will feel so much better whenever


you go back to them. Um, and of course I


know before like futures trading and I


was only in trade locker to where I


could still trade uh crypto on the


weekends.


I loved it at the time because I was


like I hated weekends because I couldn't


trade. And so whenever I started trading


crypto then it was like I have something


to trade for the weekend. And I like


quickly realized that, you know,


literally 7 days a week I was in the


charts. And I could almost feel that


like addiction to the charts, you know,


to where if I wasn't looking at the


charts


and maybe if I was, I don't know, family


function or watching a movie, I I could


always like tell in the back of my head,


I wonder what that's doing. I wonder if


NAS, you know, finally went up. And of


course, I would always picture that, you


know, I missed out on like a 100 pip,


you know,


move or something and that would, oh, I


better go check just to make sure, you


know. And I think once I like recognized


that um I didn't like that I was um like


filling that pool so so much um that I


think that's whenever I started just


stepping away and um you know having


days where I don't even you know I guess


I do look at the charts because I will


still mark them up.


Um I'll still mark them up in the


morning and then of course when market


closes and opens back up I will um you


know or while market is closed I will


adjust them if I need to. But other than


that, you know, I'm now able to get in


the charts and rearrange, you know, and


update my lines if I need to and


immediately walk away. And I think I


needed to pull myself away from the


charts to kind of kick that that chart


addiction


because I could also feel myself getting


that chart fatigue and you know whether


it was you know um losing trades


um feeling like I was forcing trades you


know I wasn't sticking to some of my


rules


And you know, I could just kind of feel


myself, you know, kind of going


backwards. And yeah, once I, you know,


started making that rule to not trade


every day, I quickly realized whenever I


would come back into the charts, um, my


trading would be so much better cuz it


was almost like


I could just see see things clearer, if


that makes sense. So, um, so yeah, I


just wanted to kind of do a quick call


on, you know, chart fatiguing, not to,


you know, get yourself to where you are


either burning out or burned out. Um,


you know, just kind of different things


that you can work towards to not get


like that. Um, you know, especially with


scalping, it's so easy to, you know, you


get that quick um almost like dopamine


and you end up wanting to chase it and


and we're working with such, you know,


quick movements anyways on those lower


time frames that, you know, even if you


get that quick shot of dopamine from


hitting say a take profit. It's like


your brain immediately wants to feed


that again and it feels like it needs it


over and over and over again or you


you know you quickly get to where you


the winds don't matter. You just are


always wanting to chase that next one.


And


yeah, more times than not, anytime, me


personally, I would do that, I would end


up at the end of the day, I, you know,


maybe I took 10, 15 trades and I may


have been up, you know, $1,000 on that,


you know, maybe the first couple of


trades that might have hit take profit.


And then at the end of the day, I would


be so wore out from trading and looking


at the charts


and then my overall P&L


I would either, you know, maybe only be


in profit


20 bucks and I'm like, "Wow, you know, I


just spent, you know, basically 8 hours


on the charts and I only profited 20


bucks and it was like a huge huge wake


up. I would get so irritated and then I


would be almost so fatigued


that even whenever markets open back up,


if there was a really good trade


opportunity, I either wouldn't see it


because I wouldn't even be looking at


the charts or I just wouldn't even care


to set it. I'm like, I don't even care.


I want to look at the charts. I don't


even want to set any trades tonight. And


that's whenever I would miss like my


perfect setup. And


yeah, it was just a huge wakeup call for


me. And of course, I recognize that a


lot in the chat whenever I see it


because I see myself in in a lot of


y'all. Um, whenever I see y'all, you


know, kind of talking about that chart


addiction,


um, I know exactly what you're feeling.


And


these are just kind of some of the


things that helped me


uh kind of break that


and and be still healthy with the chart.


So, um, don't burn yourself out. Don't


give yourself chart fatigue. You know,


don't start forcing trades. Um, you


know, feeding that FOMO feeling,


every bad emotion that can come with


trading,


you know, it'll kind of feed that. And,


you know, just whatever you need to do


to kind of minimize that as much as you


can. And I think taking a break from the


charts is one of the best ways to do


that. Um, you know, partly um it's a big


reason of why I kind of did the um like


the butterfly challenge for this month


because I feel like,


you know, if some of y'all are probably


uh like I was, you know, where I spent


so much time in front of the charts, I


didn't even step outside and


let alone exercise. So,


um, so yeah, if you can, you know, pick


a time to I'll trade during this time,


but I'm still going to make sure that


I'm eating good and that I'm staying


hydrated, that I'm still drinking water,


that I'm still moving, um, you know,


walking in some capacity or just moving,


even if it's just stretching. Um,


you know, I know like for me this my


desk like raises and goes up and down


and I have a walking pad. So, you know,


if it's crappy weather outside or


I don't know if I'm just wanting to


move, but I'm just watching the charts,


you know, where I can get on that


walking pad and um but you know, just


some kind of movement to where you're


not just sitting staying stationary


and staring at the charts.


Of course, probably not eating very


good.


um you know, not drinking, like you just


don't want to leave the charts, even if


it's to go eat something. So, um


you know, I think all of that plays a


huge part in the puzzle pieces of making


you a better trader. So, you know, walk


away,


go move, stretch, walk a little bit,


preferably


outside of the house if you can to where


you don't have that urge


to check the charts,


you know, and I know a lot of us trade


from our phones, but, you know, just


keep your phone put up and don't look at


the charts while you're walking. So, um,


so yeah, maybe try just to implement


some of this stuff this month and see if


it helps you, especially if you're one


of those that are kind of feeling that


chart addiction. Um, I'll have to post a


picture that I saw over the weekend and


um, it plays perfectly


into this like chart addiction. Um, I'll


have to post it in circle, but I think a


lot of you will


understand and agree that you have had


those feelings before. But um, but yeah,


just just work on all of this stuff. The


main thing, journal, journal your rules,


journal your emotions,


and try not to waver from that any, you


know, um, make sure everything lines up


before you even get in a trade and look


at the chart. So, um, but yeah, see if


any of that stuff works for you guys.


Um, I think it will. and


you'll realize that


you will come back to the charts a


stronger, you know, trader. So, um, does


anybody have any questions kind of


regarding any of that stuff? I don't I


don't have a question, but I'm so glad


that you went over this today because


one of the feelings that I get if I'm


not sitting looking at the chart is


guilt. Like, you know, like I should be


sitting here waiting for every setup


that I can try to get in and then of


course that results in a loss and and


whatever. But so last week like I had to


step away because even Scott was like


just take a couple days off, go back


with fresh eyes, fresh mind, whatever.


Um but yeah, the guilt the guilt is what


has always been a thing for me if I


wasn't on every day all day, you know,


looking. But then I would be so worn


out, you know, just from looking at it.


So, I'm so glad you did this call today.


Like, I appreciate it.


>> Yeah, you're welcome. And I feel the


same way. I mean, I feel like that's how


I was like, I felt like um you know,


especially me doing this full-time. Um,


I think I maybe put so much pressure on


myself,


you know, to where if like my husband


was at work and I, you know, I started


cleaning the house or was cooking supper


or sit down watching TV or whatever. And


it's like if he would get off work and I


wasn't in my office, um I think I would


almost put that pressure on me like um


I I'm not even working, you know, and it


was and it was just me doing it to


myself. Um, but but I felt like if I


wasn't in my office looking at my


computer taking trades,


uh, then I wasn't like contributing in


some fashion, I guess. And it didn't


matter if I hit my profit target by 8:00


a.m. that morning and knew that I should


be done


for the rest of the day, you know, and a


lot of times I would be done for the


rest of the day. But if


if I was sitting in the living room and


somebody were to come over and it didn't


look like I was working,


um I would almost like feel guilty about


it and you know to where it's like,


okay, even if I'm not trading, I need to


at least look like I'm working and I


need to be in my office. And I'm like,


you idiot. Get the hell out of here.


that word contributing, that's that's a


big one for me because since I'm


retired. Um I always feel like I need to


be contributing more and of course the


trades don't always work out and and


whatever. Yeah, that's that's a word


that that I use a lot too.


Yeah, I just need to be okay with with


you know maybe a trade in the morning


after open


um and then maybe power hour and then


maybe see what Asians doing,


>> right? Yeah. And of course depending on


what you're trading um


you know like I know last month uh


trading gold a lot of times whenever I'd


be watching it throughout the day


you know very rarely would I see a great


setup. Um, but then of course in the


evening whenever I was getting ready to


go to bed, I'm like the stars are


aligning and it's like this little


is now giving me a perfect trade


opportunity and I'm getting ready to go


to bed. And so a lot of it has to do


with, you know, what pair you're even


trading, you know, to where it may not


give much opportunities


until a certain session, you know, like


of course with gold and Asian session


and


then of course news and so many other


things can factor into it. But um but


I've noticed that last month with gold


is a lot of times whenever I'd sit here


and like be looking at the charts, it's


not even a good time to be trading the


instrument I was trading. So, um, you


know, it's another big thing with


getting to know the pair that you're


trading and what times of the day, you


know, does it start really moving. Um


but but yeah, I think that guilt of you


know feeling like you're contributing or


um


you know we all know in this space that


you know you may only take one trade a


day and it may be a $50 profit and that


is amazing progress and we all know


that. But of course as to like an


outsider uh maybe somebody that's that


doesn't trade or that doesn't really


understand


um you know that it's still a winning


day even if you break even uh sometimes


even if you end the day in negative uh


or if you only profit you know 10 20 $30


uh you know to somebody that's not in


this world. Um,


you know, they're like, "Well, how are


you ever going to support a family on


that or how are you going to pay any


bills with that?" But, you know, I think


that's why it's also important for us to


to have each other is we all get it. you


know, we know that


sitting and you know, my alerts didn't


go off during the day or they went off


and I still didn't see, you know, my


perfect setup, all my confluences. We


all know that's still a win. And um you


know and we can still like celebrate


that with each other to where you know


maybe our spouses, friends, family,


you know, to them they just don't fully


understand


everything that can go into trading and


you know so it you may get some of that


um you know from the the outside


influence. or whatever of, you know, you


only made $20 today or you didn't make


any money today. And and I know that


that can kind of get in our heads


sometimes and make it to where it's like


fine, I'll you know, I'll set 10 trades


tomorrow and but we know that's not not


how it it should be. So, um I did see a


question. Um see if I can get back to


it. Lisa had asked um do I notice a


difference in mindset, mood, self-care


when trading a personal live account


versus a prop firm? Uh I've only had a


handful of small accounts before, but


just wondering. Um I don't know. I would


almost say


depending on


maybe the prop firm sometimes I feel


like prop firms


can


add


a little bit of anxiety and maybe


depending on the prop firm the rules


um you know I've always tried to get in


my head anytime time I try to go for a


prop firm,


I try not to get like if I'm going for a


$100,000 account with a prop firm, I try


not to get like that dollar amount in my


head, I try to think more of


if for some reason I breach this


account, I'm out, you know, a hundred


bucks. not and I you know not the full


oh my god I just lost $100,000 account


and I think me telling myself that I'm


only out what I paid to take the


challenge


probably has helped


I don't want to say me not take it as


serious because I do take them serious


but maybe it eliminates a lot of that


stress and anxiety for for me um that if


I lose it, it's not that big of a deal.


Um


you know, to where I guess it doesn't


affect my trading if I were to lose the


account. Uh whereas my personal account


um


even though it it is my money


for some reason it's never I've never


felt that anxiety with a live account.


And I don't know if it's maybe just that


feeling of um I feel like I I have more


control over it. You know I can make my


own rules. Um,


if I want to hold over the weekend, I


can hold over the weekend, you know. Um,


you know, just kind of depending on I


guess


where the live account is, what I'm


trading. Uh, but I just almost feel like


I just have more control over it. So


maybe I don't have as much stress or


anxiety. Don't really feel like I have


like big brother looking over my


shoulder kind of thing. Um but I don't


know. But for the most part I feel like


mindset and


all of that stuff is about the same. You


know whether I'm trading a a live or a


prop account. Um,


but it may just be how I view them.


So, but yeah, if you I would say if


you're kind of noticing that maybe


you're feeling a lot of um, you know,


difference


since you've started going for the prop


firms. Um,


you know, maybe kind of figure out what


it is about the prop firm. maybe versus


the live that that is making you, you


know, maybe feel a little more stressed


out about it. Um, you know, maybe a


little bit more of that anxiety. Um,


I've always thought prop firms almost


do things to feed that anxiety because


of course they


some


I don't know I almost feel like maybe


they want they don't want us to feel


relaxed and to follow our rules and you


know they we know that they tend to make


more of their money if we fail the


challenges. So um you know sometimes I


do feel like um like they can create


some of that anxiety. But so yeah, if


you're kind of noticing you're feeling


that with a prop firm, maybe try going


to either a small live account or demo


and see if you notice any of that goes


away.


Um,


all right, guys. Well, yeah, if you


don't have any more questions, then I'll


go ahead and hop off and, um,


yeah, try all that stuff, maybe the rest


of this week, the rest of this month,


and just kind of see if you notice any


difference with your trading anxiety,


all of that stuff. But, um, all right,


guys. Well, thank you for getting on the


call and I will see you tonight at


7:00 for the live scalping. All right,


y'all have a good day. Bye.$video_22_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_22_summary$This lesson addresses the burnout that comes from overtrading, overthinking, and trying to force progress. Shea shares ways to stay consistent without draining yourself mentally.$video_22_summary$
      ELSE summary
    END
WHERE sort_order = 22
  AND title = $title_22$Eliminate Burnout$title_22$;

-- Backfill watch-page content for lesson 23: Eliminating Stress & Anxiety
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_23_transcript$Hey everyone. In this video, I'm going


to just kind of go over a few things


that


will hopefully help keep you calm and um


just not as stressed whenever you're,


you know, trading on the lower time


frames. Uh just some things that have


kind of helped me in the past. Um so,


let me share my screen with you guys.


get this pulled up. Okay, so I just


wrote some stuff down


on the chart. That way if you guys want


to take screenshots, you can. Um,


okay. So,


it looks like a lot, but I just kind of


pick whichever ones resonate with you


and really try to implement those,


especially if you're only used to maybe


trading on a higher time frame and


you're just now starting to maybe scalp


or if you've never traded at all. Um,


and you know, we'll mostly be on the


lower time frames. I know I initially


started out on the lower time frame. So,


I don't know if maybe that helped keep


me calm because I I never went from the


high extreme down to, you know, the


really low time frames.


Um, but I'll just kind of quickly, you


know, go through each of these. And so


the main thing is you want to position


your size for your comfort. Whatever


your the size of your account is,


whether it's $50, $100, or if you're


going for a $150,000,


you know, prop firm challenge or


something. It doesn't really matter what


size the account is because even if you


you are going for a larger, you know,


challenge account where you just see


that big dollar amount,


your emotions can still come into play


if you're in draw down, you know, and


you're risking too much. So just make


sure that you are you know risking a


small enough amount especially at first


to where you know if you do take a loss


and it does hit your stop-loss it's it's


not you know it doesn't trigger that


emotional response


you know so view it as just an expense


for learning the skill and not an


emotional event. Um, so I always kind of


suggest, of course, not financial


advice, uh, but I would recommend not


going more than half a percent of


whatever your account balance is, at


least initially, while you're maybe


learning this strategy and getting used


to the lower time frames. That way, you


can just monitor and just kind of see


how your emotions play into it. if you


start seeing your going down and draw


down.


Um, and then if you, you know, feel


comfortable with that and you notice


that you're not stressed, there's no


anxiety, you take a loss, and it doesn't


affect you, then you can go up to 1%.


Um, you know, once you're kind of


showing that you're able to be


profitable with that smaller percent and


of course understand whatever strategy


you're using. Um, also detach from the


outcome. So, you know, don't just focus


on if you won or lost.


You know, try to focus more on did I


follow my rules? Was I calm? You know,


did I not revenge trade?


If you did all of that, then that should


be viewed as a win. even if you may have


got, you know, your stop loss hit.


Um,


start out with a demo account. Of


course, I always suggest that,


especially if you're just kind of


getting familiar with my strategy or if


you've definitely if you've never traded


before, I start out with the demo


account and just kind of gauge your


emotions. Uh, you know, see if you're


profiting consistently.


uh understand the strategy, not making a


profit, but by the end of the day,


however many trades you have taken, you


didn't give it back, you know? So, you


may win $1,000 in the morning and get


really excited and just want to keep


going and keep going and keep going and


then by the end of the day, you're


negative 3,000. So, um, you know, just


make sure that


you're being consistent and knowing to


walk away.


Always, always, always set set a stop


loss. Um,


that's probably the biggest thing. You


never know if the charts may mess up.


You know, they may be having technical


issues and you can't get logged into


your account. Um, I know a lot of


brokers are pretty good at if something


happens and it is on their end, they'll


kind of work with you on getting that


back to you. Um, but just get into the


habit of it. That way it's there, it's


set in place, and if anything happens,


if you go take a phone call, forget


you're in a trade, you know, you just


want to have that protection there.


uh reframe your losses mentally as you


know a fee for building a skill and not


you know am I failing am I stupid I


don't understand this try to get those


thoughts out of your head because it you


know as long as you were following your


rules and all of that um


you know it it isn't that you're


failing. So, um yeah, reframe reframe


your mind, your you know, thoughts on


all of that.


Um I personally always walk away and


just stop after three losses uh max for


the day. So, if for some reason I hit


three losses back to back, you know,


there's just maybe something going on


that I'm not really aware of, whether it


be something emotionally, something I'm


just not reading on the chart, uh maybe


a big news day, big news events in the


world going on. Um it could be a number


of things. So, uh, but I don't want to


hit three losses, especially with the


percent that I risk, and turn that into


revenge trading to try to make some or


all of that back. Uh, because it


you can almost at times make yourself


see a good setup when it may not really


be. So,


personally, that's what has happened to


me.


um you know I'm like oh yeah I see a W


and then I get stopped out go back and


you know review the trade and it's like


that is clearly an EM with lower low I


mean it's just I see in hindsight


everything that I should have seen the


first time


so just you know take your time


um take breaks so you know if you're


feeling that stress and anxiety feeling


um you know, or if even if you're just


watching the charts, waiting for a


setup, but you're already kind of


feeling that like I got to get in, you


know, um I'm going to miss this big run,


you know, or whatever that you're you


may be thinking, um just if you need to


set a timer for every 30, 45 minutes and


you know, step away from the computer,


step away from your phone, wherever


you're watching the trades. Just step


away, go do something, go outside, go


touch some grass, go for a walk, just


reset. And that way, whenever you do go


back to the charts, you'll be, you know,


just more clear thinking and see the


charts in a different light.


Uh, of course, don't trade if you're


feeling emotional or stressed, sad, mad,


any of, you know, any emotion that can


affect


or um amplify


to where if you're already emotional for


whatever reason and you hit your a stop


loss and it just could kind of amplify


that because you are already in that


mindset.


So, if you're feeling any of that, just


don't trade. Um, you'll notice that


there is always, always, always, always


another trade. Uh, if you look at the


charts and you see that you miss this


huge green candle on say NAS


that just made a new all-time high.


It's okay. I mean, whenever you get back


to the charts,


more than likely,


it's going to make a correction. You


know, it's going to have a little


pullback before it continues on if it


does. So, you know, just remember


there's always, always, always another


trade.


Um,


kind of going off of that, um, don't get


FOMO. I know it's very easy to get


especially if you see people are posting


their wins and their charts and I think


I kind of touched on this on the


previous video of you know you just see


a really good setup that that you missed


out on because you were busy doing


something else. You were at your job uh


weren't looking at the charts maybe


looking at a different pair. you were on


looking at gold and a good run happened


on you know an indicy whatever the


situation may be um don't get FOMO um I


say I put ROMO


relief of missing out so


you know just there could have been


bad you know a high impact news event


and


was a perfect setup up before the news.


Everybody else got into it and they all


got stopped out, you know. Um or just a


relief that you didn't force a trade


because you personally did not see all


of your confluences lining up. So, you


decided to wait uh maybe wait until


after market open, after the news event,


and then you were going to, you know,


get back to the charts or you have a


set, you know, time frame. I'm only


going to trade between


6:00 a.m. and 11:00 a.m., whatever it


may be. And outside of those hours, I'm


not even going to look at the charts.


And you know, so maybe everybody hit all


these take profits outside of those


hours. So, you know, just feel that


relief and be proud that you stuck with


your rules or whatever it may be. So,


Romo, not FOMO.


Um,


don't compare. And I know that is


another really hard one to not do. Um,


I of course and


um I highly doubt there is any trader


out there that has not done


honestly probably all of these. And if


they say they didn't, they're probably


lying.


because you do compare, you know, well,


they started 6 months before me, you


know, um or sorry, they started 6 months


after me, but they're now funded with a


prop firm and you know, they're showing


all these profits and


it doesn't matter. Everybody learns at


their own pace. Somebody may be, you


know, have no kids, stay


stay at home, you know, housewife,


whatever it may be. They may have 10


hours a day to practice on the charts


where, you know, you try to squeeze in


that hour or two a day after you've


worked a 12-hour shift, came home,


cooked supper, clean the house, put the


kids to bed, you know, and you're still


taking that time to try to study a


little bit each day. So everybody's


situation is different. Um,


everybody learns at a different pace.


Everybody, you know,


takes different things from each


strategy. And there's just a million


reasons why nobody's just just nobody is


the same. So


don't compare.


um scalp on a time frame that you are


comfortable with. So


you know most of you probably already


know I trade on the one


mostly the one sometimes I'll trade on


the five minute but um but I'm on that


lower lower time frame um even getting


to where I I like to watch it on the 15


and 32nd. So, um,


don't do that from the get- go. But, um,


but just stay on the time frame that you


are comfortable with. You know, even if


that's starting on the 15minute,


it of course moves a lot slower than say


the 1 minute. And if you decide that you


love it there, you have time to see all


of your confluences and you know all of


that, then stick to that. Um the price


of anything that you get into is going


to be the same. It doesn't matter what


time frame you're on. Just the candles


appear quicker. So uh you know start on


the 5 minute or 15 minute if you like it


there and you are able to not feel


stressed or anxiety then there's nothing


wrong with staying on that time frame.


Um if you decide that you want maybe


something a little bit quicker than that


then you know try moving down to


uh you know 10 minute 5 minute you know


just kind of slowly start working your


way down and just you know kind of


monitor


uh your emotions


while you're doing that and


just you know you can keep going if you


want to go all the way down to the 1


minute. Uh because you I don't know have


a crazy brain like I do and


I just like seeing that quick movement.


Um for some reason it doesn't stress me


out. It


it more so probably calms me. Uh so


you know but whatever


whatever that is


you know just kind of work your way


down. So um and just you know maybe like


journal how you felt in each time frame.


Um okay let's see


let me get that up there.


Um, and then


sorry, I'm going to get this.


There we go.


Um, and then if you are on the lower


time frames, doesn't matter if it's 1


minute to the 15minute, if you're


noticing that, you know, if you are


watching the chart while you're in the


trade and you're starting to kind of


feel that anxiety because you just, you


know, you just see the candles doing


this or, you know, they're moving pretty


quick. Then you know you can see your


takerit, your stop loss, your entry


and switch over to the 1 hour time frame


if you, you know, want or just pick at a


higher time frame and you'll still be


able to see that your stop loss is still


good. You're still, you know, a good


distance away from it and,


you know, but you're not seeing that


bounce as much.


Uh so you know try that and see if maybe


that kind of helps if if you're starting


to feel that anxiety. Um you can also


try implementing the 111.


Um you know which is pick one pair only.


Um,


don't bounce around, you know, to


each time frame or a 15 different pairs,


uh, whatever it may be. um you know


don't


don't do that because you or at least


not at first or if you're feeling that


you have any anxiety uh because you


you're going to


for me anyways um whenever I first


started kind of create anxiety. So, you


know, you're trying to watch this chart


and then you jump over to this chart and


you don't want to miss what was on the


first one cuz you, you know, saw a setup


coming up. Um,


sorry if you can hear that. Um, so you


know, just try to stick with one pair,


really get to learn it, back test it,


and, you know, you'll kind of see just


the movement of it. Um, you'll get to


where you really learn how it moves and,


you know, if you don't like it after


messing with it for a week or two, then


go to another one and try that. and um


you know and just see how that works. Uh


so one pair one time frame. So if you


want to start out on say the 15minute


time frame then you know sorry watching


my grand dog and she hears somebody at


the door. So yeah just start out with


the 15minute time frame and stick with


that. Um, you know, don't don't try to


bounce around


between different time frames.


Nope. Nope. Come here. Come here. Come


here, girl. Come here.


Come here.


So if you, you know, say start out on


the 15minute, then play around with that


for a little bit and


journal how you felt, how you did on it,


and


eventually you'll kind of find a time


frame that that you really like. it's,


you know, fast enough for you, but not


too fast. And you're able to see all


your, you know, confirmations line up in


time to where you're not, say, missing


the trade like maybe on the, you know,


the one minute. It may just move way too


fast for you to like see what you need


to see without kind of forcing a trade.


And and then of course a onetoone


risk-to-reward. So if you're risking


500, set a take profit for 500 and you


know just see how well you do with with


that one one to one you know


risk-to-reward


um


you know even I don't know if you see


that you're not able to really even hit


a one to one


drop it down you know I mean there's no


set rules uh on You have to get a one


one, a one to two, a one to whatever.


You know, if you see your take profit or


price is


really close to your takerit and then


the new hour comes and you see it


pulling back and you know, you start


panicking and oh no, I it just closed it


out. you know, it doesn't have to be


like set in stone of one to one, but you


can try that out initially.


Um,


the market does not care about your last


trade, your last 10 trades, whether you


know you won or loss. It's going to keep


moving. It's going to keep doing what


what it does. Uh, so


neither should we. Sorry, all of my


writing got


jacked up and it's bugging the heck out


of me.


So yeah, just shake it off, reset,


refocus,


get away from the charts and, you know,


focus your energy forward and not what


happened, you know, previously. Um,


don't trade like you're trying to get


rich.


You know, I know there's so many videos


out there,


you know, that


just kind of promise you,


you know, start today and in a week


you'll be able to retire. And


just


don't trade like that is the goal. um


trade like you're trying to keep your


account, not lose it. Uh stay funded if


you're in a funded account, not lose


your prop firm. And you know, even if it


means


taking 3 months to pass a prop firm, I


know my first prop firm that I went for,


of course, I did not pass it. Um I


didn't fully understand the rules and


yeah, I just didn't pass it. So whenever


I decided to get another one, I it took


me about three months to pass it. I


think I had definitely some of those


mental blocks. Sorry.


Uh that I had to get past because, you


know, I never gone for a challenge


account and it it took me so long to


even go for one in the first place. So,


the fact that I did not pass it, I think


it it affected me more than maybe I


thought it did or wanted to admit that


it did.


So, I just took my time with the next


one and of course passed it. But, you


know, the first one I think I just maybe


set, you know, an unrealistic


time frame for myself. you know, I've


got to pass this in two weeks or this


month or and who knows, it may have been


because,


you know, back over here, don't compare.


Maybe I saw somebody that passed it a


lot quicker and thought if I did not do


that, I must be doing something wrong.


And it's not how it works. Um, so yeah,


just grow it as slowly as you need to.


Um, trade with your rules, not your


emotions.


And


don't forget to breathe. It's making me


think that, I think, cuz I am talking so


much. I'm forgetting to breathe, but um


I've said this so many times and you'll


probably hear me say it a lot more, but


just remember to breathe. you know,


reset your breath.


If you need you're getting ready to


maybe jump into a scalp,


if you see your setup, you know that if


it goes, you know, past this certain


point, you're getting in the trade. You


know, practice some breathing exercises


and, you know, whatever you need to do


to kind of


re regulate yourself. uh even if it's


just a deep breath. Um


that way whenever you actually execute


your scalp, you know, you'll at least be


a little bit more relaxed with your


breathing. And if you've ever shot a


gun, um you know, gone hunting,


whatever. And you know, I know I was


always told, you know, my husband would


tell me like, you know, take a breath


because I I'm sure he noticed, but um I


would notice that I was just holding my


breath. And um I think I was trying to


I'm sure just not move any of my body,


even my organs, I guess. But, you know,


so you always like take a breath


and then


go on to whatever you're doing. Um, so


just kind of


reset yourself and your focus. And um,


yeah, if I think of anything else, I'll


let you know. But I think with all of


this um


you know hopefully that will help you.


Um,


another thing I want to talk about as


far as the, you know, more


kind of, I guess, risk management,


um, is before you get into a trade,


make sure you check, um,


get it pulled up.


So it'll be Forex


factory and most of you already have


this but if not um www.4exfactory.com


it will tell you any high impact news


events that are coming up. Um, so


you know you can go through


trying to remember maybe right if you


click on there


maybe here's settings. Nope, that's not


it.


You can go into the settings


and


change it to your your time zone.


So


maybe it's right there. Yeah. So just


click on that clock. Make sure it's set


to your time frame


and then save settings. And then it'll


show you, you know, over here when the


next high impact news event is going to


be. um and not even high impact. But um


I have mine to where it will only show


the orange.


Well, actually, no. I take that back. I


think I switched that back. Um but the


only ones that you really need to worry


about are the orange and the red


folders. So, um,


trying to find right here. Filters.


Sorry, it's been a while since I've gone


into the filters. So, you can, you know,


uncclick. I don't want to know about


yellow. I only want to know about orange


and red. So, um, you know, and then you


can go to currencies. You can go to


Bitcoin. you know, you can switch


through


um whichever you want to it to pull up.


Um let's see. Apply filter. So, see it's


only showing the orange and the red.


So, red is definitely high impact. Um,


it can depending on what it is, it can


really cause the charts to fluctuate


quite a bit and um, you know, if you're


in a trade, it can shoot out really long


wicks, stop you out. Um,


and there's even some prop firms that


don't allow you to trade news. I think


five minutes before, five minutes after


if they have a I believe it's called


like a tick rule. So, uh just double


check if you are going for a prop firm


what their rules are about news trading.


And


you know, I always say I I do not trade


news. I know there's some people that


do, but I don't. And if I happen to be


in a trade,


you know, an hour, 30 minutes, whatever,


before I know a news event is coming, I


will try to at least bare minimum move


my stop loss up to break even, you know,


or a little bit in profit if I'm needing


to cover any fees or anything. Um, so


you can kind of see I can also put a


list. Let's see.


Let me see if I can find that real quick


and we'll


type it on here.


And I'll kind of


just put on here


some of the ones that I am always aware


of.


So let's see high impact


news events.


And if you ever see sometimes if I'm


typing in the chat,


I'll just do that event and I'll put


this in the you know the sling.


Okay. So there is


unemployment claims


non-farm payrolls


and I believe not NFL I believe it's


maybe abbreviated.


We'll go back and compare it though.


FOMC


which is


Federal


Open Market


Committee


CPI


PAL is speaking of course now we have


when


Trump is speaking


Okay. So, you want to and I'll put a


little note in here.


Stay out


completely if you choose to


until


we'll say 30 minutes. Sometimes it calms


down a little bit before that, but if


you want to be safe, uh, stay out


completely until 30 minutes after


news event


or


if you are already in a scout,


move stop loss to break even.


or in profit.


So if I'm already in a trade,


then


a lot of times if I know that the,


you know, higher time frame biases maybe


a buy and I happen to already be in a


buy then and I'm able to move my stop


loss up, then a lot of times I'll just


leave it because


sometimes it can go in your favor if


your stop loss is already at break even.


I want to emphasize that. Um,


don't get into it and hope that it'll go


in your favor cuz


most of the time it will not or you just


won't want your stop loss far enough


away to compensate for that safety net.


Um, so but yeah, I mean sometimes I know


there was


I don't know maybe it was last week


there was a news event with NAS and I


happened to already be in a trade and


man that sucker just shot up and it was


probably


um my top three trading days since I


started. So, um it's nice whenever it


works out. But, um on Trading View, see


this little


lightning bolt down here,


it will show you any news events. Let's


see. If I go


right here.


Yeah. So this will show news.


So you can kind of see, you know, and


then the time


what time those news events are going to


happen.


So that's nice. I I like that feature.


Um


let me try to get this


where you can see it again. Um yeah, so


you know, check Forex Factory. I


try not to get lazy even though with


like um the top step accounts, they also


have those news events on their screen,


but I still try to compare, you know,


you can see here's that CPI.


Let's see if we can find there's


unemployment rate.


Um, let's see if we can find some other


ones that core retail.


But yeah, so you can just kind of, you


know, go through, you know, it'll say


the time


7:15 a.m., you know, whatever time time


zone you change it to. And you know if


you want to look into it um I never


really have like kind of depending on


what happens during this meeting you


know unemployment claims if you know


it's unemployment's you know higher or


lower whatever it may be um


you know you can kind of monitor how it


affects your pair if you choose to you


can go through and you know read the


history. you know, a lot of them are


uh that I guess this one's this one's


maybe I don't even know which one I


clicked on, but it'll kind of give you


the history, the forecast, previous


actual, you know. So, it'll go through


all of that if you want to maybe compare


that while you're back testing and see


kind of what it does for the news


depending on if it's a a a good, you


know, outcome or a negative one. And,


you know, maybe that'll help you back


test as well. Um,


get that off of there. So, yeah, check


Forex Factory and,


you know, make sure there's no news.


Like I said, I try to check it every


morning before I get into trades just to


be aware what events are going on that


day so I know if I get in a trade at


6:30 a.m., there's high impact news at


9.


If I'm if the chart's still looking good


and I'm still profiting and still kind


of getting in and out, in and out


depending on how quickly I'm, you know,


trailing my stop loss, then,


you know, I'll either just get out and


just decide that I'm done for the day.


Um, you just kind of play it by ear if


I'm already in a scalp. So


yeah, outside of that, I think


those are the main things that can help


you stay calm. Um,


another thing I just now thought of it,


and it honestly should be at the top,


but


you know what? I'm going to put it at


the top


because it is an important one.


Journaling. Journal your trades.


Make sure I didn't have that on there


and skipped over it. Can't believe I


forgot to type it.


So,


make sure to journal. And I'm working on


kind of creating a journal so you'll be


able to plug in your answers. I know


there's like Tradezella that kind of can


do that for you and the uh top step


challenge account their platform they


also have kind of a built-in statistic


page uh which is amazing. Um, it is to


me it it feels and looks like


Tradezella. I love it. Um, since I've


gotten those accounts with Topstep, I


actually haven't even checked my


Tradezella. So, um,


yeah, we'll um we'll kind of go through


all that whenever I'm in a in a trade


and and everything. Okay. So, yeah,


journal


your


wins, losses.


I'm sorry. Just a second.


Okay. Yeah. So, journal your wins,


journal your losses,


your emotions


before the trade, during the trade,


after the trade. Um, what else was I


going to put on there?


Once I get that kind of um built, then I


will upload that maybe like in a Google


Drive.


Um, I'll have to kind of kind of work on


that and um, but I'll add that Google


Drive. That way you can go in and edit


it and add your own answers obviously.


Uh, but yeah, journal your wins, journal


your losses, journal your emotions. Um,


you know, maybe


you can list your confluences.


you know, did you follow oops your


rules?


And then like I said, I'll uh


I'll put all of them inside that


journal. So, um but yeah, just journal


all of your trades and you'll be amazed


at


what that what that tells you. Um, you


know, even if you maybe don't feel like


you were emotional or anything, um, you


know, whether something was going on


in your private life, work life, family,


kids, whatever. um and you didn't


realize how bad it was affecting you,


but then you go back and review your


trades and see that maybe, you know,


your focus wasn't


wasn't fully on that chart. Um, it's


pretty interesting to go back and and


just see and if nothing else, uh, you


know, print them out and, you know, or


save them in your computer and to go


back and look, um, at how far you've


come. I know whenever I first started, I


was writing


my journaling down and I never journal


about anything. And I never really have,


but but I wanted to journal just


everything. You know, I woke up, I'm


feeling this,


you know, this is going on. This is, you


know, or everything's great. I'm looking


at the charts. I feel calm. I feel


focused.


I didn't wake up and immediately jump in


the chart before I, you know, wipe the


eye boogers out of my eyes. And I'm


still in bed. I can't really even see


the chart, but you know, I overslept and


I need to get in the charts right now.


Um, and don't do that.


But you know, so just like journal, you


know, I got up, I


whatever your, you know, routine is,


you know, of course, I like to get up,


go to hot works, go for a walk, you


know, with our dogs and,


you know, so just journal all of that.


um you know, meditate,


you know, your Bible study, you know,


whatever whatever it may be to kind of


just calm your nervous system. Um yeah,


journal all of that and


you'll be amazed. I know. I think what I


was going to say whenever I go back and


read my journals uh from the beginning,


it's um


it's kind of comical


um to just kind of see


I don't know just how I traded I guess


and how much I've grown. So, um,


yeah, definitely do that. If, like I


said, if nothing else, it will help you


with your trading, but if nothing else,


it'll show you how, you know, proud you


should be for how far you've come in


really a short amount of time. I I don't


think a lot of you realize how far you


have come. You know, I know I talked to


a lot of people and a lot of you that


are in here and you maybe have only been


trading for


a year


or whatever it may be and


you're already doing so well. And I


think if I you put it into perspective


of whenever you go out into the


workforce, you know, whether it's when


you're 16,


you're 18, whatever it may be, and


you just start working because that's


what we are told to do. and you


just know in the back of your mind, I'm


retiring at 65


and and you're okay with that, you know,


which is fine. There's I mean, there's


nothing wrong with that. A lot of people


do that. But I think what I'm trying to


get across is


you don't think about it. You don't


rush. you know I need to be you know I


started working at a as a receptionist


and in six months if I am not running


this company


I'm going to wonder what is wrong I'm


going to give up I'm going to quit you


know right here I am failing I am too


stupid for this job you don't quit


though you just keep going and you learn


more and you get better and you practice


ractice and you create that muscle


memory and


slowly, you know, after say 40 years,


however long, uh you know, you've you


can look back and see how far you've


moved up or just how better, you know,


how much better you've gotten at that


job if you stayed in that same position.


um you know so give yourself some grace


and just think that


it doesn't have to be


you know


I don't know one you don't have to win


at trading


in a certain a set amount of time


especially a short amount of time um it


sometimes it happens to some people and


sometimes s it doesn't um sometimes it


never does. You know, trading just is


not for everybody and and that's okay.


Um but yeah, so just give yourself some


grace and


just think that if you had just started


a job in 6 months, would you be a


professional and know everything about


it and


do your job


at the same level as if you had been


there for years and just view,


you know, trading the same way. So,


whatever got me on that soap box, but um


yeah, so just if you're willing to give


any job


a large amount of time, schooling,


whatever it might be, then do the same


with trading and just learn at your own


pace. So um that will also help your


anxiety and your stress level and


therefore it will really help your


trading. So I hope this helps you and


let me know if you have any questions um


or if there was something that maybe has


helped you that that I did not mention


in here. and I can just kind of add a


list and,


you know, we can help each other out


with different things that maybe have


worked for you. So, okay, y'all have a


great day and I hope y'all are already


practicing the strategy. If you are, I


hope you watch this, especially if you


start feeling anxiety, and I hope it


helps you a little bit.


All right, guys. Well, I will see you on


the next call. Okay, bye.$video_23_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_23_summary$Shea shares practical ways to stay calmer on lower time frames and reduce trading stress. This is about building steadiness so fear and tension stop controlling your decisions.$video_23_summary$
      ELSE summary
    END
WHERE sort_order = 23
  AND title = $title_23$Eliminating Stress & Anxiety$title_23$;

-- Backfill watch-page content for lesson 24: Q&A Session 1
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_24_transcript$Okay. So, um on today's call, you know,


I made that post last week about, you


know, if there was just anything that


anybody was still struggling with or


needed clarification on any of that


stuff. I wanted to make sure that we


kind of uh get, you know, get these


issues, you know, or clarification


settled pretty early on. I don't want to


just kind of let things kind of um go on


if it's something that you're struggling


with. So, um periodically I'll kind of


do these calls and we'll just kind of


make sure that everybody is feeling more


comfortable either with support and


resistance lines or whatever it might


be. So, I just kind of took some from


that post and I'm just going to kind of


slowly go through each one of them. Uh,


I'll probably do that on today's call


and probably next week's call also. Um,


it'll kind of tie in. I know at the


beginning of each month I always do a


Q&A anyways, so it'll kind of tie into


that. But um but yeah, I just want to


kind of go over some that was on that


post from last week. Um let me share my


screen and I'll get a chart pulled up.


>> Hello.


>> Okay. So, we will uh just ignore these


trades that I got into


um on this morning's call. I'm just kind


of letting them letting them run


through.


Um okay so the um


first thing that I want to mention is


I've of course noticed a lot of post um


either you know frustration


um you know confusion on all of your


confluences are there you know still get


stopped out all that stuff um which of


course it obviously we all know it


happens no matter what. But the one


thing that I did want to maybe uh


suggest to you guys um I know we're all


kind of at different


you know levels whether you know some I


know have been trading for a really long


time. Some maybe have only been trading


for I don't know 6 months or less, you


know. So, I know we're all kind of like


at all different levels and I know we


all trade different things, but I know a


lot of y'all trade NAS um you know, with


me. Either you're kind of testing it out


or you know, you trade it because you


see a lot of other people talking about


it. Um, and I just kind of got to


thinking the other day that


I think if you're if you're not used to


trading NAS for one, um, and


or maybe, you know, kind of while you're


getting comfortable with the strategy,


all of that, I want to maybe suggest not


trading NAS. Um, just because I know I


know I can get frustrated with it and I


feel like I've traded it for a long time


to where I


I don't know, I just I know how


unpredictable it is. And so I think if I


ever get stopped out, even though


obviously, yes, it does suck. Um,


I don't even want to say that I just


almost expect it, but it doesn't


surprise me. So, um, if you are trading


NAS and you are kind of in this, uh,


phase right now of like you're really


frustrated


either with trading, you're, you know,


you question if you should quit trading,


all of those kind of emotions,


um, that I know NAS can feed, then I


want to maybe just suggest to step away


from NAS. Um especially if you want to


trade something that moves kind of


similar to it but is a lot um lot more


forgiving than um you know S&P this ES


um you know it moves


like pretty similar to NAS. So um and if


you've never kind of really looked at


them. So this is the one hour on S&P and


like this is the one hour on NAS. So you


can kind of see that they move like kind


of right alongside


each other but you know for one S&P is


cheaper. Uh but it's also just a lot


less for or a lot more forgiving. So um


it's a lot less volatile.


um you know so if you are wanting to


trade maybe an indicy


uh but you're kind of feeling that


frustration I did want to throw out


first and foremost uh to maybe get away


from NAS um so I would almost go as to


far as far as to say maybe even try like


a a forex pair um you know like I know


Euro USD D is one that I mark up every


week. Um, odd USD are like I know the


two big ones on um, futures that I mark


up and you know, but obviously there's,


you know, if you want to trade um, or if


you're on like Trading View,


there's more pairs on there obviously.


So, um, you know, and if you ever want


me to add a Forex pair to the Sunday,


um, chart markup, just let me know and


I'm more than happy to add that. Um, of


course, if you are trading maybe gold


and you're kind of feeling that


frustration, gold is another one that's


pretty crazy. um they both have kind of


been that way, especially over the


summertime. And so I don't want, you


know, you to


maybe just stick with those pairs and


you're and just continue to be


frustrated and make it to where you


just, you know, either burn yourself out


or get to where you just hate trading.


um cuz a lot of it could be the pair


that you're trading and not necessarily


trading in general. So um yeah, maybe


try, you know, silver um you know, it


kind of is like S&P and NAS. They kind


of move,


you know, in sync. Uh but it's cheaper.


It's, you know, a little less volatile.


So, you know, just kind of play around


with


a different pair um if you've mostly


been trading NAS because that very well


could be a huge problem. Um or a huge


maybe not problem, a huge reason uh for


your frustration that you might be


feeling. Um cuz I know a lot of times if


I'm looking in the chat and I see a post


about the frustration and the all of


that stuff. Um if I look a lot of times


you're trading Naz and and I just know


how


how she is. I know how bipolar it is and


one week you love her and the next week


it's like f this. I'm done trading. Uh,


but I promise you it's not you, it is


NAS. So, uh, wanted to get that out


before I forgot. Um,


another question and another thing I


think I'm going to start doing, um, is,


you know, there was some questions about


like the support and resistance lines.


So I think on like calls and I'm going


to try to remember that no matter what


I'm kind of showing uh whether it's you


know just repetitive going over the


strategy


um I am going to like completely mark up


my chart with you guys. So, um, let me


let me just pull up one.


Actually, let me find one that I don't


even have marked up.


Let's try natural gas


cuz I feel like this is one like in the


winter time.


I'm like surely it's going to go up in


the winter. So,


and it may not be a a good one to


I'm just going to kind of quickly look


and see if it how it's been moving. Of


course, it looks like it's been moving


sideways.


Let's not do that one.


Okay, here's one that kind of looks like


it has a okay trend. So, I'm going to


just kind of blindly go in and mark this


up and kind of just show you guys what I


look for. Kind of zooming out. Um, you


know, looking to the left, how I kind of


confirm on the lower time frames. Um, I


know I kind of went over it a little bit


this morning on the call, but um, but I


know not everybody was on that call. So,


okay. Of course, first thing I do is I


get on the 4hour chart


and this is where I want to


just kind of start marking off. So, of


course, I want to go with the high


I'm going to check the dates.


It's Friday the 26th.


Okay. So, this is where I just kind of


and I'm kind of looking down here at the


bottom of the screen at the date.


So, this was Friday.


And this is where I'll just kind of


start looking to the left


and see


if anything lines up.


And of course since


you know now it's


mid morning


if I was just now looking at the chart I


would already be looking at these


because I wouldn't want to put my for


our, you know, say resistance down here


whenever we're already kind of moving up


for the day.


So, for now,


I'll just kind of start looking at this


candle right here.


I'm just looking at my crosshairs


to see if I need to take into


consideration the wicks.


But for now, I'm just going to keep them


there. And then we might adjust it when


we get on the lower time frames.


>> Hey, can I ask you a question real


quick?


>> Yes.


>> Um, how come you wouldn't put it up um


where those other one, two, three


fractals like down from there? But right


Yeah, that kind of Why wouldn't you put


it right there? Because it's you want


the the soonest high. So, don't get


confused about


it being a little bit higher recently.


Uh well, so this is where Whoops. Let me


move this. This is where I would


probably meet be watching it for um like


the next uh breakout destination,


but um like I don't want to go too far


back initially. Um so like was it these


right here? This area that you were kind


of talking about? Yeah, because it hit


it so many times right there.


>> Yeah. So, like right now that is


almost a week ago. So, I don't want to


like for today.


>> Yeah. Like it's a little too far back.


Now if price comes up here and you know


gives like more candles up here and say


you know it lines up like this with


those where these crosshairs are then


that would be even better because I have


like a more recent price that also lines


up you know with previous


>> Oh yeah,


>> which is fine. Uh, but initially I want


to try to go


um


like as as the most recent


area that I can. Um, and even though,


you know, there's not really much that


lines up, but I don't want to go, you


know, if you look right here, I don't


want to go that far down. even though


that area would be, you know, like it


doesn't really line up with these. It's


just kind of there's not much that lines


up with it. Um, other than, of course,


like these, you know, these these wicks


kind of go into the area.


These candles kind of stop


um, you know, so for now. And then, of


course, these two kind of stopped in the


same area. So I want to try to go, you


know, with the most recent area if I


can. Um, so hold on, let me get this off


there.


Let me get this line. So like for


instance like even though this one this


top or this green and this red candle


are on today's date


if I'm looking for my bottom support


you know I won't do that like I won't


just go cuz it would just put me like


right there. So I know from my support I


need I will have to go you know probably


back into last week. Okay. So, that's


where I will go and look at Friday and


I'll kind of see, okay,


this was the low right here, this wick


of the green candle.


So, I want to look I always want to try


with the candle body first. I don't want


to include the wicks unless I get down


on like the lower time frame and see


that like maybe I do need to. But for


now, I'm just going to look and I'm


going to see if anything to the left


lines up if I put it at the candle body.


And of course, these candles


right here kind of line up


and these kind of, you know, price kind


of had a hard time, you know, in this


area.


So, for now, I'm going to kind of keep


it in that area


and then I'm going to keep like going


down


and then we'll check it all out again on


like the 5 minute time frame.


So, same thing on the 1 hour. I just


want to kind of


shrink it down. And I just use my


crosshairs


and I try to see if I can find an area


that there was


hesitation at.


Okay. So, you can kind of see price had


a hard time going above it right here.


Kind of went below it right there, but


that may have just been, you know, a


quick kind of liquidity


grab before it went up.


So price kind of hesitated right here


kind of right there. So if you see kind


of just when I shrink it up, you can


just kind of see.


And then same thing with the 15minute


So you can kind of see price hesitated


quite a bit in this area.


And then so once I kind of have like the


general area of where I want my price to


be


actually while I'm on this 15 minute I'm


going to go ahead and put one right


here. And that's just going to be like a


caution.


Why it does not look yellow to me? I


guess it is. Okay. And then I will go


drop down to five minute.


The one minute is almost like too busy I


guess for me to double check this. But


this is where I want to just kind of see


if I need to adjust my line. So since I


don't block off, you know, an area of


hesitation, I just do, you know, my


single lines. I know that there's a lot


of times that like I could be off a


little bit. So, this is where I just


want to kind of check and, you know, I I


still won't include these little what I


would assume is the liquidity grab, but


I want to make sure that I'm not too off


of like these little areas. So, if I


just get my 4 hour and just drop it down


to where it's kind of hitting more


in these areas,


but not including what is probably like


a wick.


And then I just kind of do the same


thing with every other line.


Kind of the same up here.


And sometimes you can use your


crosshairs and


kind of double check it before you move


it if you want.


So I'll just kind of adjust it.


And then to me like that is that's good


for me to just kind of leave it and


you know then readjust


at whenever market closes. Um, so I know


I've told y'all, but in the mornings


whenever I first came in, you know,


probably about 600 6:30, I will update


my lines with whatever might have


happened throughout the night and then I


will, you know, leave them until market


closes. The only time I ever adjust them


um is like the all-time highs. So like


this one


and like I know NAS gold


if it is creating


new all-time highs throughout the day


that is the one


candle or wick that that I will


continuously update like as long as I'm


in the charts and trading that


particular you pair then and it's


hitting a new all-time high and then


pulling back and then going up again and


creating a another all-time high. I'm


continuously


like marking this line up. I want to


always know where that all-time high is.


You know, cuz say for instance, we have


a pull go all-time high and have a


pullback and I'm wanting to get back in


in a buy position. I want to always know


that we could be going up to that


previous high. And so, I just always


want to know where it's at.


Um, so before I kind of hop on to


anything else,


um, was there any questions that y'all


can think of like right now that have to


do with support and resistance?


And while y'all I'm going to just kind


of peek in the


chat.


Nat


So, um, one of the questions was, do I


always have, uh, do my 1 hour above the


15 minute? Um, I always I probably more


tend to


want to


>> Nope, I don't know what that was. Oh,


that was the the Nash trade we were in.


Um, so whenever where I see price


hesitating


more is where I kind of want to put my 1


hour just because it will hold more


weight. Um and and I don't know why, but


it seems like more times than not my


15minute


um will sometimes end up like closest to


current price. So, I don't know if it's


just a kind of coincidence that my lines


always kind of end up like that, but um


but yeah, my one hour is just whenever


I'm kind of shrinking my screen down


where I see the price kind of hit the


most. Um that's kind of what I want to


watch for more than more than anything.


Okay. So, I don't think my 1 hour is


always above the 15minute, but there's


probably a lot of times that, you know,


it could be.


Um,


let's see. Yeah.


But yeah, I think as long as you are


marking off the areas of hesitation


and you know, even if say this line


right here you have is your 15 minute


and you know your 1 hour is down here


you know or or something like that and


they're just maybe you have this the


general area marked off um you know


that's pretty similar to where my area


is but like the color is different.


I wouldn't worry too much about that cuz


I feel like no matter what color my


lines are, whether it's this, you know,


just caution area


um or whether it's my 1 hour, um I'm


pretty cautious


if it gets near any of my lines. Um now


of course my 4hour support and


resistance those are pretty um like


solid to me. Um, I will always


be extra cautious or if I see price


rejecting off of it and I start seeing


my confluences, I will um, you know,


kind of hold more weight


from a a 4hour bounce than say if it was


just from my 15minute. I know that this,


you know, or uh sorry, this little like


say yellow caution area. I know that


price can just blow right through that


and not hesitate at all. Um but I will


still use caution. So, if you know, say


if I'm in a sell and price starts


getting near this area,


I will kind of watch it just to make


sure that, you know, we don't get a


reaction off of it and it goes back up.


So I think as long as you have your


areas marked off where you see that


hesitation,


then just try to get in the habit of


using caution. No matter if it was your


1 hour, your 15 minute,


you know, because it there was a reason


why there was hesitation that you saw


that made you, you know, mark it off.


and you just want to kind of make sure


that it's not going to have another


reaction to it.


Um, okay. Another question that I've


seen and kind of wanted to go over was


in a,


you know, a pair that is kind of a,


you know, just keeps going almost like


NAS, um, you know, gold,


um, you know, where we just see a good


continuation and you don't want to jump


in, of course, you know, at the tail end


of it and then get trapped or obviously


get stopped out. Um, so as far as what I


look for in a kind of a continuation


trend, uh, where something's really


moving and


I maybe have missed out on the what I


feel like is a majority of the move. um


either not looking at the chart or


>> or sleeping, you know, or whatever the


situation might be, but um but just


where like maybe I feel like I like


missed a lot of the move. Um


it one it kind of depends on where price


is. So say if I was to open up my chart


and prices like right here on this


candle, I would be a little more


hesitant


because um we are near my 4hour


resistance area. So


kind of depends on where price is based


on like my uh my 4hour support and


resistance especially.


Uh but of course even if it's in any


other area of hesitation. Uh but


regardless what like I would never want


to just hop in on this like if it was in


here where I just see green green


you know and there's no pullback. Um, I


would always wait for a price and


sometimes I do miss out on a lot of


moves. Um, because I know like gold for


instance is one of those that whenever


like she starts moving, I mean sometimes


it just does not stop. Um, and I know


I'm on the 1 hour time frame. So, you


will see like a little more pullbacks,


you know, on the lower time frames.


So, let me


let me hop down kind of show you what I


would wait for.


So,


say if price is going up,


I was trying to find a time of maybe


where I would


get on the chart like maybe 6:00 a.m.


Let's see where.


Well, of course, here at 6:00 a.m. it


was at the 4hour support, but


yeah, say if it was just in this area,


for instance. So, we'll get kind of in


between a support


u you know, different 15minut and 1 hour


support levels. So,


I would either wait for,


you know, a pullback


and depending on what time frame you're


looking at, it's going to look


different.


uh but for instance say the 5 minute


I want to


see a pullback


and then almost like if I was blindly


looking for all of my confluences again.


So you might not necessarily get the EMA


cross. Uh which is fine sometimes. You


know it'll just do this. it'll just pull


back into it, but it won't necessarily


cross. Um, so that's probably the only


confluence that maybe I won't get if I'm


wanting to get in on a continuation, you


know, trend that just keeps going. Um,


so but I do want to see almost all of my


other ones. I want to start seeing, you


know, another higher high, a higher low.


Um, you know, maybe a breakish


structure. Um, if I get a pullback that


starts doing this, it's almost even


better for me if it kind of does that


consolidation


because I feel like it gives me a good


structure to watch for that I want to


wait for it to, you know, break


structure. So you know even if you just


kind of act like this 1 hour support is


not there and we're like say in between


then I want to see something like this


or I hope that I will see this um and


then I want to see you know the break of


structure


the higher high


and then of course higher low and then I


feel a little more comfortable with then


getting in. So, but I do want to see a


little bit of a pullback and then


confirmation of my confluences again.


Um, so like I said, the only one you


might not get is the EMA cross.


Sometimes you will see it, you know, on


the one minute.


Let me see if I can kind of get back to


where this was.


So, let's go Friday at like two.


Let's see what this looks like.


Okay. So, right in here. So if we were


watching this on the one minute time


frame,


so you will get the EMAs cross on a


pullback.


So


that's where you would want to just wait


for confluences. So if I was to be


waiting


for my confirmations on the one minute


time frame, you can see that, you know,


we have this pullback.


It just kind of starts ranging.


We get the EMAs crossed again, this


break of structure,


higher lows, higher highs.


Whereas, of course, on the five minute,


you know, you kind of had the same


confluences, but it just wasn't u enough


of a pullback for the EMAs to cross. So,


that's kind of what I will watch for if


I've noticed that, you know, I've missed


out on a strong upward or downward trend


and and I don't feel like I, you know,


want to just blindly jump into it,


you know, especially if it's been going


for for a while.


Um,


okay. Let's see. Let me look at my


notes.


Um, another thing that kind of kind of


goes along with that is the all-time


highs. Um, I know if you know you're


kind of we kind of went over I guess


marking them off where I will kind of


always update my all-time high um, you


know, line and


just kind of be watching for that. But,


um, you know, as far as like when to get


in an all-time high, uh, I kind of will


use the same as what I just went over.


Um, I will not get into it if it is


right up at an all-time high area. Um,


because I I think I just always feel


like there's going to be a pullback. If


you go back and look at, you know, gold


NAS whenever they hit those all-time


highs, a lot of times there's a pretty


good pullback, you know, maybe even a, I


don't know, two or three day candles


worth of a pullback. Um, so I will


either, you know, let it let it do a


little bit of a pullback. If I feel


like, you know, it's tell everything is


telling me that we're just going to keep


going up and create new all-time highs,


I will wait for a pullback. Um, if I'm


not already in it. And, you know, I want


it to just take a little bit of a break


before I get into it. Um, you know, I


wouldn't just


I'm trying to find an area, but


like if this was our all-time high, like


I would just not blindly hop in. I would


want to see, you know, some kind of


pullback and then watch for my


confluences again. So, um, so I feel


like, you know, just the confluences,


it's almost like if I'm blindly looking


at a chart, I want to start them all


over again. I want to see the pullback


and then I want to start checking them


off. You know, higher highs, higher


lows, EMA cross, depending on what time


frame I'm looking at. Um, you know,


break a structure, W's, M, all of those


things. Um,


and on this morning's call,


sorry, I don't remember who it was.


Maybe Robin, can't remember, but she was


saying that if you know, she's ever kind


of uh struggling with like the support


and resistance lines. I did think it was


a really good idea.


she switches to the line chart because


of course the line chart will not take


into consideration wicks which is kind


of what I try not to look at cuz if


they're just liquidity grabs you know or


whatever but so if you kind of feel like


you're questioning your lines


try to do what you know she does and


flip over to the line chart and see if


maybe it helps helps you, you know, kind


of see things a little bit better. Um,


and kind of play around with that.


Um,


there's a couple other things, but I


don't think I really have time to go go


through them right now. So, I might save


some for next week. Um, so if there was


a question that didn't get answered,


like


don't worry, I'll, you know, I'll go


over that next week. Also, um,


I I don't use hyenashi. I used to, um,


and like periodically I will look over


at hyenashi,


like maybe if I'm questioning if I


should just close out of a trade. Um or


maybe if I'm wanting to, you know, trail


a little bit closer. Um sometimes I will


like hop over to the hikenashi. But


other than that, I I don't know. I


haven't looked at those in quite a


while. But um but yeah, definitely if if


you kind of want to shut the noise out


and


maybe take some of the emotion out of


it, like if you're definitely I would


say if you're already in a trade and you


know, you just are kind of seeing a lot


of this up and down, up and down, um


just to kind of I guess calm your


nervous system down a little bit, hop


over to the hyenashi


And you know, that way you can kind of


see like if you're in a buy right here,


you know, and you can see, you know, the


wicks, if it's having a pullback, you


know, on the hour candle,


you can hop over to the hyenashi and see


that, you know, the trend looks a lot


prettier


looking at those candles.


Um, okay. So, before I forget, um


I do want to


go over the um the golden glow.


And for all of y'all that were trying to


go through the chat looking, I'll just


let it be known that she has joined the


call. So, she's in here now. Or she was.


I don't know. I guess I could uh let me


scan it real quick just to make sure.


Yeah, she's in here. Um, okay. So yeah,


I just I don't know why, but probably


because I just can't ever not try to


think of something to give me to do, but


um but I was sitting there thinking and


you know, it's like whenever I look


through circle


uh part of like the the daily check-in,


the weekly check-in,


all of that stuff. And I just I notice


even if I'm not in there chatting a lot,


um I do notice that like I can tell


y'all are putting the work in. Just the


fact that y'all are willing to update


your charts. I know that a lot of times


can be, you know, there's a lot of


accountability


to being vulnerable enough to upload


your charts, let alone trades that you


may have taken.


Cuz I mean, I won't lie. I know there's


some trades that I'm taking I'm like,


there's no way in hell I would ever tell


y'all I just took that trade. Um, even


if I may have won the trade and hit my


takeprofit, it would have seemed so


ridiculous that I even got in it, maybe


not one confluence was there. It was


just like a I have a gut feeling this is


going to and I would just get in it like


so stupid. But um so anyways, whenever I


see y'all uploading your charts,


um you know that you'd be amazed at what


that is doing for your trading journey.


Um even if it's uploading charts that


hit your stop loss, um it's still


there's still so many benefits to it.


Um, so I just thought that I want to


just recognize,


you know, somebody that that for one,


she does this, but I see a lot of y'all


doing it. Um, and it's like I can see


the growth almost weekly whenever I see


their charts pop up. Um, I can like I


just hope anytime I see that like


they're frustrated, I'm just like, "No,


you're doing so good." Like, and I know


it doesn't feel like that to you. But,


um, but just know that I'm not the only


one that has noticed because we've


gotten votes.


Obviously, y'all voted for this and and


we got multiple votes uh for you. So,


other people have seen it as well. Um,


so with this little award, um, I just


want to do two free months, um, you


know, membership fees or whatever. Um,


just to kind of show you that we we see


you and we support you and want to kind


of just reward you. Um, so the first


golden glow, kind of hard for my tongue


to say that. Um, is Jackie Beers.


So I think she did hop on the call. Um,


so we'll kind of get with you, Jackie,


and


kind of figure out the u the membership


thing, but um but yeah, we just want to


let you know that we're so so proud of


you. Um,


and I don't know if many of you guys


either know or don't know this, but


Jackie's been trading for I know she's


been trading longer than I have. Um, and


I've been trading for I guess a little


over right at two years, I guess. I


think two years in August. Um, and I


know she was trading before I was. Um,


so you know, whenever you guys see that


maybe she's having fresh a frustrating


day or um, you know, just know that like


she did not just start last week. I


mean, she


puts in the work and she she knows what


she's doing.


So,


you know, she just I don't know. I don't


even know like what words I'm looking


for, but but just know that she has


never stopped putting in the work. um in


the last you know 2 years that I've kind


of been trading alongside her um you


know she's an OG ho and


like we have just seen


like the work that she puts in like she


does not quit and yeah so I'm I was so


happy that you guys saw it also um cuz I


know that you know me and the other


admins


you know, we've kind of talked and you


know, we obviously all see it and but


we've all kind of been trading alongside


Jackie. So, um I feel like sometimes it


was easier for us to see because we we


know her history.


So, the fact that you guys all saw that


was amazing. I feel like all of the


votes that came in uh we were just like,


"Yes, yes, yes." It's like we agreed


with every single one of them. So, um


yeah, I think I'll just kind of maybe


randomly do a post um you know, before


like I announce it again.


um you know, but if randomly if you see


that somebody's doing something that you


want to recognize or caught your eye or


whatever, feel free to just DM us


whenever and you know and we'll keep


track of like if just people get voted


for. So, um, and definitely keep posting


your charts and, uh, and hopefully you


will


get the award next time. Um, okay. So,


real quick before I end this call, I'm


just going to make sure that, um, there


wasn't anything in the chat


that I needed to address.


>> And before you end the call, I just have


to say thank you. Um,


I don't want to cry cuz like I mean this


is cool but it's um I've had quite the


past 24 hours and um


this is just a real turnar around. So


thank you.


>> You're welcome. I'm like trying to like


read the chat so you don't get me like


get emotional while I am the one on


camera.


Um, yeah, I was wondering that too. I


assume her daughter has her distracted


right now.


Okay, guys. Um,


yeah. Yeah. So, um, yeah, definitely


just keep keep them coming.


Like I said, we'll keep track of it. And


um


yeah,


I think that's I think that's it. Um so


next week's call um and I know I'll see


y'all tonight, but next week call next


week's call um I'll kind of go over some


other questions that you know, of


course, we're on that post and we'll


kind of walk through some more things.


So, um, if there's anything else y'all


can think of, you know, I think I'll do


a Q&A call or a post before next week's


call. So, if there's something between


now and then that comes up, let me know


and I can just kind of squeeze it in on


that call. Um, all right, guys. Well, I


will see you guys tonight at um on the


live scalping call this evening. And


um if not then I will see you guys in a


circle. Okay. All right. Talk to y'all


later. Bye.$video_24_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_24_summary$This Q&A answers common sticking points from students and reinforces the core ideas from earlier lessons. It's a practical cleanup session for questions people still have after working through the material.$video_24_summary$
      ELSE summary
    END
WHERE sort_order = 24
  AND title = $title_24$Q&A Session 1$title_24$;

-- Backfill watch-page content for lesson 25: Q&A Session 2
UPDATE public.videos
SET transcript = CASE
      WHEN COALESCE(btrim(transcript), '') = '' THEN $video_25_transcript$Okay.


And I'm just kind of sharing this screen


just so I can kind of go over a couple


of things like on a live chart. Um, so I


think the first thing that I've kind of


seen a few times is um,


let me turn off that or close the chat.


Um,


is the limit buy or stop by limit sale


kind of the difference in those? And


like I said, I I have to keep like a


post-it note because I think I always


just question which one it is. Um, but I


think an easy way for me to kind of


remember it is, you know, if you


rightclick


and of course market buy, market sell,


stop buy, limit sell. So, if you think


of, you know, even though you see like


obviously the buy and the sell, but kind


of these two, it's like why aren't they


the same? Um, so the stop, if you just


want to kind of think of it as, you


know, if price hits this level, like I


want in. So, um,


you know, like you want to be kind of,


uh, picky with, you know, I don't want


in on this, you know, gold or whatever


it is unless price hits this, you know,


dollar amount and then I want in on it.


So, you're buying into,


you know, the commodity or whatever


you're looking at. Um, and then of


course you'll see I don't know if it'll


show it on here. It won't, but like on


Trading View, if you're in a a trade,


the stop loss will show a um a stop


sell. So, um, and that's kind of like


the same thing like if if price gets to


this level or this price, I close me out


like I want out of it, you know, protect


my money, whatever. So, you'll you will


see the stop buy to get in and then


depend on what chart you're trading on,


the stop loss will have a stop sell. So,


you know, you just kind of want to like


stop, like if a train's going, you want


to stop to get in and then you want to


stop the train to get out. Um, and then


of course limit sell


you, you know, you're kind of like


limiting


your money. So, I want to save my money.


But if price gets down to this cheaper


price, uh, you know, then I think that's


a pretty good deal. So, I want to go


ahead and get in on this sale, this


deal,


you know, and that will set a pending


sale. So that and of course market buy


market sell uh that will just put you in


at market wherever you you know right


click at. So


you know of course this is at 39849.


So if you were to right click it's just


going to immediately put you in. And of


course you can see


by one that's just contract. So, however


many contracts you want to buy, um, you


know, you will pick that on whichever


option


you are looking at. And then in case you


weren't on the live call this morning,


this position bracket that's on the new


Xplatform.


So whether you're on top, top one, um I


don't know any other ones that


maybe are using Xplatform, but uh this


position bracket, if you click on this


little gear box


and check this to automatically apply


risk and profit bracket to new


positions, you can put your risk, you


know, dollar amount.


Oops, didn't mean to click that. You


know, so $500 stoploss,


$500 take profit. So if you want it to


automatically set a one to one for you,


then you know like cuz there's sometimes


if like I don't know, you want to set a


pending before you go to work or set a


pending before you go to sleep. Uh but


like before or at least as far as I knew


of


once I hit that pending and it triggered


me in then I would have to wait to set


my stop loss and my take profit and I


just didn't like that because you know


if I for some reason missed the alert


that I had set on Trading View or Trade


Locker uh since we don't have alerts


dead on X, then I may not even know that


I got triggered in. So, I like that


pending thing or the position bracket


cuz if it does trigger you in, it


automatically like this right here. I


had set a pending on the live call this


morning. As soon as it triggered me in,


it immediately put my stop loss and my


take profit at the $500 amount that I


set. And then of course if you you know


like down here with it being a micro it


put it really far away which is you know


good. It's a good uh good protected stop


loss for a while. Uh but if you want to


move it you know I mean you can still


move it even if it you know since it


preset it. Um but


yeah and you can do of course the same


with take profit. So I like this


position bracket. I would definitely use


that if you are planning on you know


setting a pending at least so you know


you will have a stop loss on the chart


and then you know you can set one to two


or whatever but the important thing is


to make sure you have a stop loss on the


chart. Um, and then of course, you know,


we know you can rightclick


to set those


or you can of course come over.


Let me put the DOM on here. You can put


the DOM on your screen


and you can do the same thing over here.


Whoops. I don't want to do that.


But yeah, so you can either set it on


the dom or just right on your screen.


And one good thing or one neat thing


that um


sorry I don't remember who said it,


Lutrina or Lisa, I can't remember. But,


um, she had pointed out something that's


pretty neat


if you're kind of wanting,


you know, curious


maybe where to put


like your take profit. Let me get back


on the same same screen. I don't have


these linked up.


There we go. So you can see over here it


has this P&L


and I don't know how long if that's


always been there. I usually don't use


the DOM but on my phone app


in like the trade section I think on the


bottom I noticed that it had this. So, I


don't know if that's a new thing or


what, but um but yeah, if you're kind of


curious, you can see,


you know, if price gets Let me move this


over so we can see.


So, we got in at 39756.


So, of course, here's our entry.


And you can see if you put it at this


price, your takeprofit, you know, is


$23.


And of course, the same with your stop


loss. So, I thought that was kind of


neat.


Okay, Trina, I knew it was one of you


two.


Um


Oh, okay. Yeah, that's a good idea. So,


I didn't I didn't realize that you could


Let me get that back up.


So, you can look at this before


before you set a trade.


And I think maybe you have to be in it.


I may have misunderstood what you just


said.


Okay. All right. Yeah. So, um, but yeah,


I think that's like really neat that you


can kind of look and see, you know,


where and of course it has high of day


marked on there. If you I know like


trading view I have the trading sessions


pulled up but if you don't I don't know


why it won't let me have that


but


of course you can see this is where my


stop loss is


but yeah so you can kind of play around


with that and it will it will tell you


where the high of day is you know so


like if you want to kind of use that for


a takerit or a stop-loss, especially if


we're at like all-time highs. Um, you


know, you can just kind of play around


with that. But, but yeah,


I like I like that that is there.


Okay. Yeah. So, like Trina said, if you


get into like your practice account and


set one, then you can kind of gauge,


okay, if I put it at this price, it's


roughly going to be, you know, $500 uh


take profit.


And then there was um


I'll share something in circle today


that um that somebody shared that I


think kind of helps you figure out how


many ticks, you know, a stop-loss is


with how what price it is and all that


stuff, but um I have not added that. So,


okay. Okay. So, do y'all have any


questions with the stop buy, limit sale,


any of that before I kind of move on to


the other questions?


Okay. So, another question that I've saw


a couple of times um is regarding like


the M's and the W's. Um,


you know, I'm I don't remember if like


y'all were kind of having like a hard


time seeing them. Um, I know one of them


was asking like how


like precise I am with it and you know


as far as like if the second Let me draw


this out. So, like say if we were


looking at this W right here


and you see that that fractal is lower.


Um, she was asking if you know I would


not consider that a W or not use that or


I'm pretty sure that's what she was


asking. Um, and I


definitely prefer for the fractals to be


higher, but I will sit on it even if


it's not. So, for instance,


if I was looking


down here whenever price was reacting


off this 15minute resistance


and I was starting to wait for my


confluences


and I see Whoops, that is the wrong


tool.


Here we go.


And I see this W forming. And of course,


it's not a beautiful W, but I still see


I would see that as a W. So, you can see


this fractal


is lower than that fractal, but I still


see a W. So, I don't worry too much


about the second point being, you know,


lower in a W or higher on an M,


you know, but if I see what looks like a


W to me and then I start seeing all my


other confluences,


so you know, EMA cross, break of


structure,


that's good for me. Um, so again, if


Switching over to the line chart can


sometimes help you find the W easier.


So, you know, you can, of course, my


line's going to jack with that one.


Let's not do that tool. But you can see,


you know, this W right here, even though


this second point is lower,


um, I'm okay with that.


So, I'll kind of show you


another example. So, here's another W,


of course, with the higher fractal on


the second point.


So, I mean, if you want to only use the


ones that have the the higher points,


you can definitely do that. Um, but I've


just always found that


I don't know. It doesn't doesn't really


matter to me. Um, you know, if one is


higher or lower. Same right here.


this M right here.


Of course, we had a lower second point.


And


here is an example of one that had a


higher point.


So, you can see that, but it still is an


eel.


So, I don't know if it's because I


initially started out with the line


chart and no fractals. So,


I was, you know, setting them anyways


without using the fractals or seeing if


the points were higher or lower. Uh, so


I don't really, you know, if they are,


that's even, you know, better. Like this


one right here where the second point is


higher. Um,


I obviously like that better, but um, if


it is lower, it would not stop me from


setting a trade. Um, let me make sure I


didn't miss anything else that they were


asking about that.


Um, another one that was kind of grouped


in with that was the higher highs and


higher lows. Uh, whenever I'm looking at


those, uh, she was asking if I used only


the candles or fractals and I will use


fractals. Um, so that is the one thing


that I will look for on that. So like if


I was um trying to find an example with


so like right here we had a fractal and


then you know we had some lower low


fractals or sorry candles. Um I would


if I was just kind of looking at


that is the confluence that I was


waiting for. I would want to wait until


I see a fractal. Um, I think it just


kind of confirms to me that, you know,


there's been enough candles and we're


taking a breath to give us a fractal.


So, I do look at the fractals whenever


I'm taking into consideration higher


highs, lower lows, all that stuff. Um,


so yeah, that's probably the one thing


that I do definitely use fractals with.


Okay, let me


kind of go through these questions.


thinking there was another one with M's


and W's.


Sorry, I lost that that question.


Okay. So, I think she was just kind of


asking


um you know or saying that whenever


she's looking for M's and W's, she like


makes herself see them. Uh, which I've


obviously done that too. Like I'll look


at, you know, some of this junk right


here and like I do see a W, but it's


messy. And I I feel like if you are


questioning if you are really seeing a W


or an M, I would say either go to your


line chart and see if that's showing the


same thing where you're kind of taking


the noise out of, you know, um the


candles and all that stuff, the colors


of the candles where you're just kind of


looking at where price went. Um, so you


know, because of course the ca the line


does not consider the wicks. Uh, it's


just where the candle bodies moved. So


that might help a little bit to see them


or at least confirm if you think you're


seeing one.


Another thing that might kind of confuse


you is if you're kind of seeing them


like in this stuff, you know, where it's


like, "Oh, is that an M? Oh, nope. It's


a W. It's an M." And you're just kind of


going back and forth between the two.


then I would just maybe not trade it


because it's either ranging or you know


it's not given like a clear


signal of you know that it's a W or an


EM forming. So, if you're kind of


questioning that, I would maybe just


wait until you see some of your other


confluences


and then, you know, and then kind of


base it off there cuz I mean, sometimes


price will move really fast and there's


not really like almost like right here,


you know? I mean, it just came down and


then we didn't really get too many like


pullbacks to create a clear W, but you


know, you just kind of go off your other


confluences. So, of course, we had a


reaction off this EMA cross, break a


structure.


So, that's where you can kind of decide


if like you don't have to have that M


andW. I've definitely taken trades that


didn't have like a clear one, but you


could also go to, you know, another time


frame and see if you see them on there.


Like a lot of times I'll kind of flip


through the time frames, not to set


trades, but just to kind of see, you


know, like this right here on the five


minute. Couldn't really see anything on


the one minute. But if you come over


here, you know, you can kind of see


there's a big W.


So sometimes even doing that um you know


y'all know obviously I have done the 15


30 second sometimes I even hopped over


to like the 30 second chart and you know


see I think it was this one


like I'll kind of


tell myself like okay well I kind of see


a W on the 302nd. Um,


even on the the 15 second, you know, and


I don't use the 15 or the 30. I


definitely want to clarify that. I will


not use those to set trades. So, like I


would not use this confluence of, oh, I


see a EMA cross and a break of


structure. I wouldn't do that on the 15


second, but you know, but I it does help


me maybe see like a W where there's a


little more there's more candles. So,


you can kind of see the pullbacks a


little better.


But yeah, don't get in the habit of


looking for confluences on the 15 or 30


second cuz it would probably not work


out very well or it wouldn't for me


anyways. Um, so yeah, try the line chart


if you're having kind of a little


trouble seeing the M's and W's or


questioning them. And um, and then of


course go to u maybe a different time


frame and just see if you are seeing


maybe an M or a W


on there. Um and then of course um


you know a fractal will form um I think


I just saw a question come through uh


you know whenever there price stops and


we're pulling back or you know going in


the opposite direction. So, you know,


where price will stop and I think it was


usually based on


trying to remember. I think I'm getting


it confused with um with the EMAs, but I


think that's maybe like the five candle


average or something like that. But


don't don't quote me on that. Go check


on the um the fractal video and and


that'll be the correct answer. But but


yeah, whenever it detects that price is


stopping and we're having a pullback,


it'll give you a fractal.


So it's basically telling you, okay,


this was the low and now we're having a


pullback.


Okay, let's see. We talked about the


stop by limit


and I know I have talked about um


all-time highs


as far as like what I wait for you know


on entering them since you don't really


have


like say a 4hour you know um area to


kind of aim for um but I'll kind of go


over that again because I did get


another DM about it. So, a lot of times


whenever I am looking to get into a


trade and it's at an all-time high, I


will of course look at the higher time


frame bias. Um and it depends on what


I'm trading. So, if it's like a Forex


pair, you know, or something like that


where I know that it can go up and it


can go down. Um,


I just kind of go with the flow of it, I


guess. But with like NAS and gold,


I know y'all heard me say this thousands


of times, but I always feel like they


are going to continue to go up. Okay.


So, if I do get in a sale,


I have to almost really convince myself


based on the higher time frame bias that


we're getting a pullback. Um, so that's


where like with gold for instance, since


we're on this chart,


I will kind of just pop and look over


at like the daily. So obviously you can


look at the daily and see we are we are


in a bullish market with gold. We are


just going up. You know we see these


little pullbacks


just to continue to go up. So I will


always look and see when we had our last


pullback. And of course this one was I


think Thursday was the second. you know,


we had a a pullback and then of course


we're going back up. And then I'll do


the same with the 4 hour. And I'll just


kind of look see when we had our last


pullback. Um, you know, if I feel like


it needs to take a breath at some point.


I know we did, you know, this one


started out as a sell candle, so that's


like a little breath, but of course


buyers took over by the the end of it.


and we have a green candle.


And then I'll kind of do the same on the


1 hour. So went up, had a breath up, of


course, we started ranging


and then going back up.


So I'll kind of just look at all of that


and decide, okay, we did take some


breaths. I feel like we could continue


to go back up. If I look at it and I


feel like it's due for a pullback,


especially if there's like any high


impact news or anything like that where


I feel like um you know, I don't know if


it's POW or CPI or something like that


where I know it could really move the


market, then I sometimes will start


questioning, okay, we're in a very


upward trend, but if news hits, you


know, that could drop it and, you know,


sometimes it'll drop it down into a fair


value gap that I maybe have marked off,


but you know, the news will maybe like


drop it and then we might go right back


up. But I feel like that's like, okay,


there's a good pullback that feel like


we haven't had in a while. Um,


so I'll just kind of, you know, look at


that. Of course, we're on the 15minute


time frame, but you know, that was two,


so 30 minutes worth of pullback there.


Um, you know, so I'll kind of like gauge


all of that, the higher time frame bias,


and then kind of decide from there.


Okay, I feel like, you know, we're good.


We should continue to just keep


climbing. And that's where I will wait


for all of my confluences like this for


instance, you know, I mean, we are in


between the break the all-time high.


Actually, Mark, move that up a little.


We're at the all-time high and in


between that and the 4hour


resistance. So,


you know, it would be better like we did


have a little pullback. I guess right


here we came across had a pull back into


it, you know. So, we did have a few like


retest where it did not go below and


start selling. I I always like to see


that. I don't want, you know, if it was


just doing this and we didn't have a


pullback, I would wait. You know, if


this right here, this section was up


above this 4 hour resistance and I just


saw going up up up, I would want to see


a retest, you know, down into this area


before I decide to get into a buy.


But um but I would I would wait like


this.


Trying to think whereabouts I got in


or what time it was.


Maybe it was this candle. It was like


towards the end of the call.


I bet it was. Yeah. So like this candle.


So like whenever I was looking to set


this pending, you know, of course we had


retest retest


um you know, even this one right here. I


mean, I can see a W here and then I can


see a W there. I'll mark this off so


y'all can see it.


So I saw that W.


Of course, we failed to go below. We had


a higher low. We had a higher high. I


had my EMAs cross. And so for me, that


was good enough for me to go ahead and


said, and I don't know. I guess this


would have been


maybe there would have been the all-time


high whenever I set the pending,


you know. So, it was really close to


that all-time high line that I had. Um,


but I don't really consider that,


you know, like, oh, I won't do that


until it crosses over. Like, if it was


the 4hour resistance, of course, I would


not set a trade right here, you know,


cuz I mean, I obviously I know that it


could come up and just keep going up.


But this all-time high, you know, I


don't necessarily


um


only look at it as a resistance level,


even though I know it it can be for


sure. Um but


if all of my confluences are telling me,


okay, we may have had our pullback and


we are going to create all-time highs


again, then I'm okay setting it. I might


be a little like cautious.


Of course, my stop loss, normally it


would not be down here. It was just cuz


I had that preset $500,


but I would probably put my stop loss.


Let's see. We'll just mark this with


blue real quick. I would want it below


this area.


So, we're below this 4hour resistance


and then I want to be below this low.


So, if I was just setting it and it


wasn't like the preset amount, that's


where it would be.


And then, of course, my take profit,


I would just initially set it at a one


one. Um, and then, you know, maybe set


an alert maybe like halfway like


somewhere in here,


you know. So, of course, this right here


is a one one. So, you know, maybe like


a.5 or something. I would put an alert


right there if I wasn't watching it. and


um


you know and then if it started getting


close obviously I would maybe just keep


moving it up if I was sitting at the


computer but initially I would be good


with the one one and then of course once


it got you know about right here that's


whenever I would move my stop loss to


like break even or maybe even in profit


and then just give it room. Um, one


thing that I am going to try to do this


month, uh, kind of for the challenge is


I am hoping that the charts are finally


going to calm down. Um, you know, we're


in the the last quarter, we've gotten


through the summer months, we've gotten


through August, you know, September was


even kind of blah. Uh, so I'm hoping


once we've now that we've gotten through


all of that, um, that the markets will


kind of like calm down a little bit and


not be so crazy and unpredictable. Um,


so what I'm going to try to do is not


trail my stop loss. Um, I will just


because I I'm going to be trading either


with gold or NAS. Uh, so I'm always kind


of cautious with those. But I will set


my stop loss and I will either leave it


completely and not move it up. Um, or I


will do, you know, like this. I will


wait until it gets between my entry and


my takerit. Whether that's a, you know,


if I set a one to two, then I'll wait


till it hits a one one. Obviously, this


is a one one. So, if it gets to like


that, you know, 0.5, then I feel like


that's a good distance away, you know,


for it, you know, maybe to breathe.


Hopefully, it doesn't pull back and


knock you out. But, but to where I would


at least want to be break even or, you


know, a little bit into profit just to


like help cover any fees. Um, and then


that's probably going to be the only


time that I move it. I won't like I have


not been moving up and trailing with um


with fractals like I normally did. Uh


just because I feel like


we're maybe getting to a point to where


I don't have to be that cautious. Like I


was uh so cautious during the the summer


months just because price would just


wick, you know, like crazy and hit my


stop loss and then go back up, you know,


to the direction I was in initially and


I just wanted to always protect my


capital. So I was always moving up to


break even and then trailing with uh


fractals, but I'm not going to do that.


And I think I've been kind of playing


around with that maybe like for the last


week and and it's been okay. I mean, I


know that a lot of this has just, you


know, we've had a really good upward


trend, but you know, I've even gotten in


sales on gold,


you know, so like seeing this right


here, it definitely


is having a hard time get getting past


this dollar amount. Um, I did see


something that they were kind of saying


they thought that gold would possibly go


up to this 4,000 price range. Um, so I


feel like it definitely could also maybe


even more, who knows? Uh, but I will


watch for a good pullback. Um, you know,


so we are ranging right now. Of course,


it's almost 11 o'clock here. So market


slows down around this time anyways,


you know. So we'll kind of see what this


does through like the lunch hour and


then of course the the power hour u the


last hour before market closes. I'll


kind of watch and see what it's doing.


But if we go I would say below


this level right here which with this


break of structure. If we get out of


this range and we come down to this


4hour and break through it and then come


back up retest a couple of times which


of course would give us our m. If I see


that, then I would think, okay, we might


be getting a good pullback. Um,


let me look at


the Forex real quick.


So, tomorrow


on Tuesday, Central time,


we have


we have some orange folders at 9:00 a.m.


and 11. And then of course at 8:00 PM we


have some red folder news. Uh Wednesday


we have FOMC


and then of course some pretty big ones.


Thursday and Friday uh being the first


part of the month. But um you know so we


may just kind of do this until we get to


a high impact news day. Maybe even


tonight. I know there was a couple of uh


red folders, but I'm just not familiar


with them enough to know how they would


move this stuff. But um but yeah, we may


just kind of move slowly. Who knows? we


might keep making all-time highs and


then whenever news hits those red


folders, I would say more likely like


the Wednesday, Thursday,


Friday, those three days is when we


could possibly see like a good daily


candle pullback. So, you know, we may


have some good like bearish moves on the


lower time frames, but I feel like we


have just been going if we continue to


keep going, you know, today


u even tomorrow if those folders don't


really move it too much, you you know, I


mean, we could just keep slowly making


all-time highs and then whenever that


news hits, that's where we might get,


you know, a good pullback. Uh, so I'll


watch for that. And if I start seeing


that, um, then I'll start just kind of,


of course, looking to see where my


support and resistance lines are. And if


I start seeing all of my confluences


that were in a sale, then I will


definitely get into a sale with gold.


But


but I just know that it will probably


not last long. So I will be a little


careful. Um


okay, let's see. So all-time highs. Make


sure I didn't


miss anything else.


Let me check the chat real quick.


Okay. See, I missed a couple weeks due


to my son's wedding. So, I will go back


and watch all the videos. However, uh


can you go over the caution line that


you are now using? I missed that


explanation.


Are you using that on all symbols or


mainly NAS since it has gotten so crazy?


Yeah. So I a lot of times it is because


a lot of them have been like ranging so


much. Um let me see if I have one on


here. Okay, I do. I Yeah. So I feel like


you know I'll always do of course my my


normal ones um you know my 4hour one 15


minute all that. Uh but then if I'm


looking at the chart and see like the


consolidation areas, but price kind of


really respected that. Um I wouldn't


necessarily put like my 15minute down


here just because it's so far away from,


you know, current price. Um, so I would


want to get like this right here, like a


little bit closer to price,


but I want to be aware of this area


right here where we had just it ranged


for so long and really kind of respected


this price right here. So, if price were


to come back down to this area, I just


want to be a little cautious with it um


and know that, you know, price really


ranged in that area, you know,


whatever a few days ago whenever it was


down there. Um so, yeah, I've just kind


of done that with really any chart. I


mean, gold has kind of been acting the


same, you know, where we had a lot of


kind of times where we were just


ranging. And you know, I would kind of


make me feel like like even this right


here,


like if you look at where I have my


crosshairs, funny enough, where about my


entry is, you know, but if I was to put


a line right there,


you know, you can see it almost would


look like an area of support. Let me


change this.


Guess that is yellow. It doesn't look


yellow to me. Um, but yeah, so you know,


price kind of really had a hard time


getting above it, then it came down and


tested it. So,


like maybe tomorrow or something


whenever I'm redoing my lines and


marking up my chart, I'll kind of see if


this lines up with say like a 15minute,


then that's where it would more than


likely be. Uh but if not or if I see


another area that you know looks a


little better, I would probably put that


caution line right there just just


because it kind of really stuck to that


price range. Um, and then of course if


um I don't know if you've heard me like


did you are you familiar with like my


green line


and you you may have been on like some


of those calls um with like the Okay, I


was making sure. Yeah, just marking off


the one hour. So,


I definitely didn't want to confuse


anybody with um you know that being like


a resistance even though funny enough


sometimes when I mark it off


it uh kind of turns into that


which let me move this up.


Yeah. So, of course, the gold we finally


busted through


this structure


and


we will we will see what it does. I'll


kind of put a line to show y'all where I


roughly,


you know, and of course I would see what


the price is, but


roughly just somewhere in the middle.


If price comes up here, I will move my


stop loss up.


But for now, we'll just we'll just see


what this


this little girl wants to do today.


Um,


okay. Let's see. Let me look through


some more questions real quick.


I think I've answered most of these.


Um, if you are wanting to use the


trailing option and wanting it to


automatically trail your stop loss, um,


whenever I, you know, if price gets up


here and I move my stop loss up, that is


when I would turn on the trailing


stop-loss. and you know, however many


cuz you can pick like however many um


you know, ticks or whatever you want it


to trail it then that's where you know


wherever I had my stop loss at to


you know there. So roughly I don't know


20 ticks away. So whenever I turn that


on,


that's whenever I would turn on the


trelling, you know, for it to give it a


good distance for, you know, like this,


like let it pull back, you know, if it


needs to, but my stop loss would be far


enough away to where hopefully like the


first pullback it didn't knock me out


kind of thing. Um, so that's whenever I


would trail it. Uh definitely New York


open. Um I know a lot of y'all,


you know, if you're trying to trade that


and it goes crazy like of course it


does, uh you know, it will wick you out


and then of course go back in your


direction and even hit like where your


take profit was. And I I know that is so


irritating. Um, but you know, like


always with me, if I'm not in a trade


already, like if I'm looking at the


markets, you know, pre-N New York open


and I see that, you know, the London,


you know, the end of London is moving


nicely and giving me a really good entry


because a lot of times, of course, it


can just be a lot smoother movement.


there's not much volatility,


um, then


of course I will go ahead and get into a


trade. But I will want to make sure that


my stop loss is, you know, protected at


New York open. Um, and I know sometimes


whenever I do that,


depending on, you know, for one, if I'm


even green whenever New York is getting


open, which I hope I am. If not,


obviously, I just leave my stop loss


where I had it and


accept that my stop-loss amount, I'm


okay with losing that. Um, you know, I


never do more than, you know, I need to


or whatever to be safe. But um


but yeah, if I'm able to move my stop


loss, then I will move it to break even.


If New York open wicks me out, you know,


and then keeps going up, I'm okay with


that. I will let it calm down,


you know, sometimes like 10 to 15ish


minutes, uh depending on how crazy it


gets. But whenever I can tell that it's


kind of slowing down a little bit and


you know confluences are still there


maybe even you know if it goes crazy and


then we start having the pullback like


the correction of it uh but it's just a


pullback then you know I would start


like say if this was New York open and


we went up and then it started calming


down coming back you know then I would


just look for influences again. So I


would wait EMA cross all that stuff. Um


so that's kind of how I would navigate


New York open or how I do. Um


of course there are times that


that I will get in when it's going


crazy. But um but if I ever do that, I


will make sure that my stop loss is


far enough away to where like those


crazy New York open wicks like won't get


me out. But but yeah, just always make


sure whatever your stop loss is, you're


okay with losing that, you know, and


and just walk away. I mean, if it if


you're in a trade or get stuck in a


trade and it starts going crazy, you


know, like I say, hop over and watch it


on a higher time frame so you're not


seeing all those, you know, crazy


pullbacks and wicks and all that. But


yeah, just just whatever you set your


stop loss at,


except that it's already gone to where


if you lose it, it's fine. Um if not,


you might be risking too much. Um


you know, and so you just kind of want


to


just kind of change that if you know if


that's what you are doing, adjust your


stop-loss. Don't risk as much. You know,


maybe use the micro and not the mini. So


just kind of play around with it and see


what you feel comfortable with. Um but


yeah, New York open can be a little


crazy. Um if I don't see any


opportunities in the morning whenever


I'm trading,


I will sometimes look around, you know,


2 2:30. I'll start looking around 2. Um


you know, and then like that last hour,


45 30 minutes.


that's whenever you will see, you know,


they really come back in and move the


markets some more. So, um there's a lot


of times that I'll get in trades at that


time, and I used to not do that, but um


but I've noticed like with NAS, if it's


ranging most of the day towards that


last hour, we'll get some good movement


and then I'll be, you know, obviously


done for the day. But um if I don't see


anything, then I just don't trade that


day. But yeah, New York open, I have to


see a good setup


to even get in a trade before New York


open hits.


U


Amber, so whenever the uh last hour that


I look is uh 2:00 p.m. because on this


on the top step uh


And I think even with my take-profit


trader challenge account, I have to be


out. I think top step is 310


take profit. I don't know. It's either 3


or 3:10. Uh so I can't really trade like


that 3 to 4. But yeah, 2:00 p.m. Central


time until like 3 is, you know, I guess


the power hour that we can trade.


Anyways,


you're welcome. So, yeah, if you don't


find any movement at New York Open or


it's just too crazy and you don't want


to trade that,


totally fine. Um,


you know, if you have the urge, get into


your practice account and get it out of


your system, you know, to trade New York


open,


you know, or just enough to where you


kind of get more comfortable with it.


Uh, but outside of that, if you don't


find anything,


you know, to trade during New York open,


then, you know, take a look around 2:00


or so and see see if you see any setups


during that time. um you know that's a


little bit calmer. Uh, so like with NAS,


you know, I'm like pre-new york,


sometimes like right after New York


opens, uh, from like 2 to 300 p.m. I


will even look at 700 p.m. uh, whenever,


you know, the Asian market is opening


and, you know, kind of between like 7


8:00 like if it's if I'm trading gold,


I'll wait till like 8. But um sometimes


I can catch some good movements there to


where maybe I can set a trade,


it goes in my favor enough to where I


can protect my stop loss and then I just


let it run all night. But so I'm kind of


playing around and getting more familiar


with gold and when it can move, the


times that it moves, all of that in case


I decide to go with gold


this month for the challenge. and um


and put my nasty girl in timeout. So um


she's been good to me, but I don't know.


Gold is like this right here. It just


lacquer her again.


Um do you ever set a stop order before


market open Sunday? Hold on. Where'd


that go?


Uh before market opens Sunday. I have


been watching and when Friday has a big


move lots of times it opens up in the


fair value gap at Sunday open.


>> Um I I have set or uh like I have traded


on Sundays. Uh but I don't think I've


ever set a pending order like before


market opens I guess. Um but


but I mean that would be a good idea


especially if it was maybe like far


enough away to where you know how


sometimes like whenever market opens


they'll have that like huge gap you know


catching up with the orders that


happened over the weekend. Um you know


as long as like something like that


didn't trigger you in and then


immediately reverse. Um you know I think


that's nothing wrong with that. But


yeah, like yesterday um whenever market


open and NAS and gold both were, you


know, they looked really good to me. Um


I mean I set both of them on like my my


live accounts which for me I was like


girl what are you doing? I think I even


like messaged Melissa and or she was


texting me about gold and I was just


like I don't even know what I'm doing.


Like I had just put out that post like


one pair, one time frame, one strategy


and I was like and look at me. I traded


on the two most bipolar pairs out there


at the exact same time. But thank God it


worked out for me. But um


but yeah, that's what I do not want us


to do this month. We're going to we are


going to stick with our plan and


just do one one pair at a time. So, I


don't know. Maybe this month I'll just


stick with gold and


see if I if I will like accept her back


or not. Um if she burns me too much,


then I'll be like, "Okay, I'm going to


go back and stick with Nas. No more


gold." Um but yeah, we'll see. We'll see


what happens. Um, all right, guys. Well,


if y'all don't have any questions, I


think I answered all of the ones um that


were in that


that chat


where I had y'all kind of put any


questions that y'all were needing help


with. So, of course, if anything else


comes up, post it in circle and we can


cover it if it's something that, you


know, I need to share my screen with or


anything like that, just like normal.


But until then, y'all have fun with your


challenge. Make sure you are taking


good trades cuz


you never know when you will get called


up. um


even if it's in circle


um you know I'll just make a post and


tag you or something and


yeah but I will want um I think I've


probably put it in the post but um if I


call you up in circle you know make sure


that you're sharing your um chart what


trades you took and of course like your


P&L


Um, like we're not just going to mark up


charts and be like, "Oh yeah, I took


this trade right here." Like I want to


see it in your P&L. So, um,


so yeah, good luck and have take good


trades.


Even if you lose a trade, that's fine. I


mean, you don't we don't want you to


just share the trades that you won.


Like, realistically, we know that's not


going to happen. So, um, so if you lost


a trade, don't worry about it. We will


look at it with you and, you know,


whether you kind of already knew why you


shouldn't have taken it or not, we'll


help you kind of dissect it and and just


know it's okay. But I think doing the,


you know, one pair, one time frame, um,


you know, all that one strategy.


I think that will really kind of help


with a lot of anxiety, but on top of


that, it will let you know if you just,


you know, if you start out and you want


to do the 5m minute time frame and at


the end of the month, you're like, I


freaking hate that time frame. I want to


move up to the 15minute or I want to go


down. It's too slow for me. But it'll


give you a good chance to really get to


know, you know, what what you like and


what you don't like and give it a good


chance to not bounce around. So, um I


think it will really help, you know,


with your trading. So,


um


>> J, I got to tell you it really because


today I didn't let myself take a trade


in my combine unless it was like A+


golden trade and I'm only 200 from


passing. I'm like, "Thank you, Jesus."


>> Yes.


>> So, it's already working. It's already


working.


>> That's awesome. Yeah. And I feel like


with me,


you know, like I was only trading NAS. I


was only trading the one minute,


you know, like I was kind of already


sticking with that. But but I do feel


like if I ever lost any trades, it was,


you know,


like just because it wasn't, oh, I


didn't wait for this confluence or I got


in here and I should have got in here.


So, I think that definitely helps, you


know, with your confidence


>> and and then it helps, you know, what


what happened to you. you know, you get


more confident to where you're like,


"Okay, I know I'm looking at this and I


can tell this is a good golden trade.


I'm setting it." So, it helps you just


be a little more, you know, picky and


hold yourself accountable. So, that's


awesome. I'm excited for you.


Okay, guys. as well. Um, if you don't


have any more questions, then we'll go


ahead and hop off here. But something


comes up, you know, throughout the


challenge or anything like that, just


throw a message and circle, you can tag


me, you know, and we'll kind of we'll


get it worked out. So, all right. Well,


I will see you guys on tonight's call uh


at


Sorry, I don't know why I always forget.


Uh 7 7:00 p.m. Central time. Um


>> Oh my god.


>> I'll see you guys on that call if you're


on there.


>> Okay, guys. Have a good day. Bye. Why


the$video_25_transcript$
      ELSE transcript
    END,
    summary = CASE
      WHEN COALESCE(btrim(summary), '') = '' THEN $video_25_summary$This second Q&A continues with real student questions and chart examples. It helps connect the lessons to common day-to-day issues that come up when you start applying the strategy.$video_25_summary$
      ELSE summary
    END
WHERE sort_order = 25
  AND title = $title_25$Q&A Session 2$title_25$;

