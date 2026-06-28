# Push MVP

## Project

**Name:** Push
**Platform:** iOS
**Framework:** SwiftUI
**Target:** iOS 17+
**Architecture:** MVVM

Push should start as a high-fidelity prototype that can become production later.

Do not build backend, authentication, real-time location sharing, or real activity inference yet unless explicitly requested.

---

## Overview

Push is a private live map for real friends.

**Core line:**
Know the move before the group chat does.

Push helps close friends understand what is happening around them without needing to text everyone. It shows where real friends are, what they appear to be doing, who they are with, and whether something social is forming.

Push is not a tracking app, not a generic map app, and not a chat app. It should feel like a premium Apple-native social layer for real life.

---

## Core MVP

### 1. Live Map

The app should center around a live map.

The map should show close friends and give the user immediate context about:

* Where friends are
* What they are doing
* Whether they might be socially available
* Whether friends are already together
* Whether something nearby is forming

The map should make the product’s value obvious immediately.

---

### 2. Friend Status

Each friend should have a live status.

A status can include:

* Place or venue
* Activity
* Availability
* Time context
* Who they are with
* Confidence level

Availability states:

* Free now
* Free soon
* Maybe down
* Busy
* Joinable
* Driving / ETA

Status language should feel natural, casual, and socially safe.

When confidence is high, Push can be specific. When confidence is lower, Push should soften the wording.

---

### 3. Friend Detail

A user should be able to tap a friend to see more context.

Friend detail should answer:

* What are they doing?
* Where are they?
* Are they available?
* Who are they with?
* Is it worth pulling up?

Friend detail should feel lightweight. It should not feel like a full social profile.

---

### 4. Feed

Push should include a feed that turns live friend activity into social context.

The feed should show what is happening in real life, not posts.

The feed should surface:

* Friends becoming available
* Friends arriving somewhere
* Friends already together
* Friends driving somewhere
* Groups forming around an activity
* Plans or possible plans forming

The feed should prioritize useful social opportunities over passive updates.

---

### 5. Who’s Down

Push should surface moments where something could happen right now.

Who’s Down should summarize friends or groups who are currently:

* Free
* Free soon
* Nearby
* Maybe down
* Joinable
* Already together

The goal is to quickly answer:

**Is anything happening right now?**

---

### 6. Pull Up

Pull Up is a lightweight way for a user to signal social intent.

A Pull Up should include:

* What the user wants to do
* Who can see it
* Basic time or location context
* Quick responses from friends

Pull Up should feel faster and lower-pressure than starting a group chat.

---

### 7. Friend Groups

Push should support friend groups.

Groups are real-world circles where people actually coordinate.

A group should show:

* Members
* Current member statuses
* Who is down
* Recent group activity
* Plans connected to that group

Groups should feel integrated into Push, not like a separate product.

---

### 8. Plan Cards

Push should support lightweight planning through Plan Cards.

A Plan Card is not a chat thread. It is a shared coordination object.

A Plan Card should help a group understand:

* What the plan is
* Who is interested
* Who is ready
* Who is maybe in
* Who needs something
* What should happen next

Plan Cards should make coordination easier than texting.

---

### 9. Privacy

The MVP should include simple privacy controls around activity visibility.

Privacy options:

* Share exact location + inferred activity
* Share exact location only
* Hide inferred activity

Do not include Ghost Mode in the MVP.

Privacy should feel simple, safe, and easy to understand.

---

## Design Direction

Push should feel:

* Premium
* Apple-native
* Social
* Lightweight
* Clear
* Calm
* Trustworthy
* High-fidelity

Avoid:

* Generic map app feel
* Surveillance dashboard feel
* Chat app feel
* Social media clone feel
* Enterprise dashboard feel

The exact UI should be refined through iteration.

---

## Technical Scope

Use:

* SwiftUI
* MapKit
* MVVM
* Mock data
* Mock services
* Local state

Do not build yet:

* Backend
* Authentication
* Real-time location sharing
* Real activity inference
* Push notifications
* iMessage extension
* Large groups
* Weekly recaps
* Dating/social graph features

---

## MVP Goal

The MVP should prove the core experience:

A user opens Push, sees what close friends are doing, understands who might be down, and can start lightweight coordination before the group chat does.
