# Elixir Rivets — Data Model Framework

***This project is still a "Work in Progress" and not ready for GA***

[Rivets](https://docs.google.com/document/d/1ntoTA9YRE7KvKpmwZRtfzKwTZNgo2CY6YfJnDNQAlBc) is an opinionated framework for managing data models in Elixir, using a series of helper libraries for elixir applications wanting help in their Rivets projects.

Library Contributors: Mark Erickson, Brandon Gillespie, Lyle Mantooth, Jake Wood

## Rivet Ecto

This library is named rivet, but is technically the ecto specific bits for Rivet,
and is largely the base needed by other rivet libraries.

Look in module docs lib/mix/tasks/index.ex for command syntax

## TODO

* configurable table prefixes in db schema
* maturing command set (see mix rivet help)
* tighter integration w/Ecto (see prior)
* tests are currently going into path/model/model_test; should just be path/model_test
* default model shouldn't create so many things

## How to use?

See rivet-ident for a project using the Rivets Framework.

You can bring the rivet-ident into YOUR project as a dependency (see notes on that project for more details)
