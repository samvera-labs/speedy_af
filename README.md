Code: [![Version](https://badge.fury.io/rb/speedy_af.png)](http://badge.fury.io/rb/speedy_af)
[![Build Status](https://travis-ci.org/projecthydra-labs/speedy_af.png?branch=master)](https://travis-ci.org/projecthydra-labs/speedy_af)
[![Coverage Status](https://coveralls.io/repos/github/projecthydra-labs/speedy_af/badge.svg?branch=master)](https://coveralls.io/github/projecthydra-labs/speedy_af?branch=master)
[![Code Climate](https://codeclimate.com/github/projecthydra-labs/speedy_af/badges/gpa.svg)](https://codeclimate.com/github/projecthydra-labs/speedy_af)
[![Dependency Status](https://gemnasium.com/projecthydra-labs/speedy-af.png)](https://gemnasium.com/projecthydra-labs/speedy-af)

Docs: [![Documentation Status](https://inch-ci.org/github/projecthydra-labs/speedy_af.svg?branch=master)](https://inch-ci.org/github/projecthydra-labs/speedy_af)
[![API Docs](http://img.shields.io/badge/API-docs-blue.svg)](http://rubydoc.info/gems/speedy_af)
[![Contribution Guidelines](http://img.shields.io/badge/CONTRIBUTING-Guidelines-blue.svg)](./CONTRIBUTING.md)
[![Apache 2.0 License](http://img.shields.io/badge/APACHE2-license-blue.svg)](./LICENSE)

# SpeedyAF

This gem provides two mixins and a presenter designed to speed up ActiveFedora-based discovery and
display operations.

**This gem depends only upon ActiveFedora, not on Hydra or HydraHead**

# Table of Contents

  * [Classes and Mixins](#classes-and-mixins)
  * [Installation](#installation)
  * [Help](#help)
  * [Known Issues](#known-issues)
  * [Acknowledgments](#acknowledgments)

## Classes and Mixins

### OrderedAggregationIndex

This mixin adds an `indexed_ordered_aggregation(name)` class method that, in turn, adds two methods
to the including class.

```ruby
class Container < ActiveFedora::Base
  include ActiveFedora::Associations
  include SpeedyAF::OrderedAggregationIndex

  ordered_aggregation :items, class_name: 'Item', through: :list_source
  indexed_ordered_aggregation :items
end
```

In the example above, those two methods are `indexed_ordered_items` and `indexed_ordered_item_ids`. They
return the same data as the standard `ordered_items` and `ordered_item_ids`, respectively, but rely more
on Solr and less on the Fedora repository. The `_items` variant returns a lazy enumerator that yields
target objects instead of an `ActiveFedora::Orders::TargetProxy`, but the effect is similar.

### IndexedContent

When mixed into an `ActiveFedora::File` descendant, it will index the resource's full content to Solr
on save. This allows the [`SolrPresenter`](#solrpresenter) to load it up without hitting Fedora.

### SolrPresenter

`SolrPresenter` is designed to load everything it can about an ActiveFedora object from Solr,
transparently lazy-loading and delegating calls to the underlying Fedora object only when necessary.
It casts indexed attributes to their correct types, loads both indexed and unindexed subresources
(See [`IndexedContent`](#indexedcontent)), and responds to most reflection accessors with another
`SolrPresenter` instance containing proxies for the desired objects.

A presenter (or array of presenters) can be instantiated by calling:

`SpeedyAF::SolrPresenter.find(item_pid)`
or
`SpeedyAF::SolrPresenter.where(solr_query)`

See the spec tests for details.

# Installation

Add this line to your application's Gemfile:

    gem 'speedy_af'

And then execute:

    $ bundle install

Or install it yourself via:

    $ gem install speedy_af

# Help

If you have questions or need help, please email [the Hydra community tech list](mailto:hydra-tech@googlegroups.com) or stop by the #dev channel in [the Hydra community Slack team](https://wiki.duraspace.org/pages/viewpage.action?pageId=43910187#Getintouch!-Slack): [![Slack Status](http://slack.projecthydra.org/badge.svg)](http://slack.projecthydra.org/)

# Known Issues

* `SolrPresenter` currently tries to grab all relevant rows from Solr at once. Future releases will
  be more mindful of both local resources and Solr request limits.

# Acknowledgments

This software has been developed by and is brought to you by the Hydra community.  Learn more at the
[Project Hydra website](http://projecthydra.org/).

![Project Hydra Logo](http://sufia.io/assets/images/hydra_logo.png)
