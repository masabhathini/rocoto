#!/usr/bin/env ruby
if RUBY_VERSION < "1.9.0"
  require 'require_relative'
end

# Get the base directory of the WFM installation
if File.symlink?(__FILE__)
  __WFMDIR__=File.dirname(File.dirname(File.expand_path(File.readlink(__FILE__),File.dirname(__FILE__))))
else
  __WFMDIR__=File.dirname(File.expand_path(File.dirname(__FILE__)))
end

# Add include paths for WFM and libxml-ruby libraries
$:.unshift("#{__WFMDIR__}/lib")
$:.unshift("#{__WFMDIR__}/libxml-ruby/lib")
$:.unshift("#{__WFMDIR__}/libxml-ruby/ext/libxml")
$:.unshift("#{__WFMDIR__}/sqlite3-ruby/lib")
$:.unshift("#{__WFMDIR__}/sqlite3-ruby/ext")


require 'test/unit'
require 'fileutils'
require_relative '../lib/workflowmgr/cycledef'

class TestCycle < Test::Unit::TestCase

  def test_cyclecron_init

    # Set up tests
    testfields = []

    # Test asterisk forms
    testfields << "* * * * * *"
    testfields << "*/2 * * * * *"

    # Test each non-asterisk form
    testfields << "0 * * * * *"
    testfields << "0-10 * * * * *"
    testfields << "0-10/2 * * * * *"

    # Test lists for each form that can follow a single integer form
    testfields << "0,1 * * * * *"
    testfields << "0,1-10 * * * * *"
    testfields << "0,1-10/2 * * * * *"

    # Test lists for each form that can follow a range form
    testfields << "0-10,11 * * * * *"
    testfields << "0-10,11-20 * * * * *"
    testfields << "0-10,11-20/2 * * * * *"

    # Test lists for each form that can follow a stepped range form
    testfields << "0-10/2,11 * * * * *"
    testfields << "0-10/2,11-20 * * * * *"
    testfields << "0-10/2,11-20/2 * * * * *"

    # Run tests
    testfields.each do |testfield|
      cycle1=WorkflowMgr::CycleCron.new(testfield,"test")
      assert_equal(testfield,cycle1.cycledef)
      assert_equal("test",cycle1.group)
    end

  end

  def test_cyclecron_first

    cycle1=WorkflowMgr::CycleCron.new("* * * * * *","test")
    assert_equal(Time.gm(1900,1,1,0,0),cycle1.first)
    cycle1=WorkflowMgr::CycleCron.new("0 */6 * * 2008-2012 *","test")
    assert_equal(Time.gm(2008,1,1,0,0),cycle1.first)
    cycle1=WorkflowMgr::CycleCron.new("30 12 15-31 4,8 2010 *","test")
    assert_equal(Time.gm(2010,4,15,12,30),cycle1.first)

  end

  def test_cyclecron_next

    # tests now
    cycle1=WorkflowMgr::CycleCron.new("* * * * * *","test")
    reftime=Time.at(Time.now.to_i)
    reftime -= reftime.sec
    nextcycle=cycle1.next(reftime)
    assert_equal(reftime,nextcycle)

    # tests first day of year; specific hour
    #   next cycle from 0000Z 01 Jan 2011
    cycle1=WorkflowMgr::CycleCron.new("0 0 * * * *","test")
    reftime=Time.gm(2011,1,1,0,0)
    nextcycle=cycle1.next(reftime)
    assert_equal(Time.gm(2011,1,1,0,0),nextcycle,
                 message="tests first day of year; specific hour\nnext cycle from 0000Z 01 Jan 2011")

    # tests last day of year; specific hour
    #   next cycle from 1800Z 31 Dec 2010
    cycle1=WorkflowMgr::CycleCron.new("0 0 * * * *","test")
    reftime=Time.gm(2010,12,31,18,0)
    nextcycle=cycle1.next(reftime)
    assert_equal(Time.gm(2011,1,1,0,0),nextcycle,
                 message="tests last day of year; specific hour\nnext cycle from 1800Z 31 Dec 2010")

    # tests next day after leap year; specific hour
    #   next cycle from 1800Z 28 Feb 2008
    cycle1=WorkflowMgr::CycleCron.new("0 0 * * * *","test")
    reftime=Time.gm(2008,2,28,18,0)
    nextcycle=cycle1.next(reftime)
    assert_equal(Time.gm(2008,2,29,0,0),nextcycle,
                 message="tests next day after leap year; specific hour\nnext cycle from 1800Z 28 Feb 2008")

    # tests next cycle from 1543Z 28 Feb 2009; specific hours
    #   00Z/12Z, every day of every month of every year
    cycle1=WorkflowMgr::CycleCron.new("0 0,12 * * * *","test")
    reftime=Time.gm(2009,2,28,15,43)
    nextcycle=cycle1.next(reftime)
    assert_equal(Time.gm(2009,3,1,0,0),nextcycle, message="tests next cycle from 1543Z 28 Feb 2009; \
specific hours\n00Z/12Z, every day of every month of every year")

    # tests next cycle from 1123Z 31 Dec 2009; specific hours; partial d-o-m
    #   00Z/12Z, 15-31 of every month of every year; every day
    cycle1=WorkflowMgr::CycleCron.new("0 0,12 15-31 * * *","test")
    reftime=Time.gm(2009,12,31,11,23)
    nextcycle=cycle1.next(reftime)
    assert_equal(Time.gm(2009,12,31,12,0),nextcycle, message="tests next cycle from 1123Z 31 Dec 2009;\
 specific hours; partial d-o-m\n  00Z/12Z, 15-31 of every month of every year; every day")

    # tests next cycle from 1823Z 31 Dec 2009; specific hours; partial d-o-m
    #   00Z/12Z, 15-31 of every month of every year; every day
    cycle1=WorkflowMgr::CycleCron.new("0 0,12 15-31 * * *","test")
    reftime=Time.gm(2009,12,31,18,23)
    nextcycle=cycle1.next(reftime)
    assert_equal(Time.gm(2010,1,15,0,0),nextcycle, message="tests next cycle from 1823Z 31 Dec 2009; \
specific hours; partial d-o-m\n   00Z/12Z, 15-31 of every month of every year; every day")

    # tests next cycle from 1543Z 31 March 2009; specific hours; partial d-o-m
    #   00Z/12Z, 31st day of every month of every year; every day
    cycle1=WorkflowMgr::CycleCron.new("0 0,12 31 * * *","test")
    reftime=Time.gm(2009,3,31,15,43)
    nextcycle=cycle1.next(reftime)
    assert_equal(Time.gm(2009,5,31,0,0),nextcycle, message="tests next cycle from 1543Z 31 March 2009; \
specific hours; partial d-o-m\n   00Z/12Z, 31st day of every month of every year; every day")

    # tests next cycle from 1543Z 28 April 2009; specific hours; partial d-o-m
    #   00Z/12Z, 31st day of every month of every year; every day
    cycle1=WorkflowMgr::CycleCron.new("0 0,12 31 * * *","test")
    reftime=Time.gm(2009,4,28,15,43)
    nextcycle=cycle1.next(reftime)
    assert_equal(Time.gm(2009,5,31,0,0),nextcycle, message="tests next cycle from 1543Z 28 April 2009; \
specific hours; partial d-o-m\n   00Z/12Z, 31st day of every month of every year; every day")

    # tests next cycle from 1543Z 31 August 2008; specific hours; specific months
    #   12Z, every day of June, July, August of every year
    cycle1=WorkflowMgr::CycleCron.new("0 12 * 6-8 * *","test")
    reftime=Time.gm(2008,8,31,15,43)
    nextcycle=cycle1.next(reftime)
    assert_equal(Time.gm(2009,6,1,12,0),nextcycle, message="tests next cycle from 1543Z 31 August 2008; \
specific hours; specific months\n   12Z, every day of June, July, August of every year")

    # tests input of wrong month/day combination 
    #   next cycle from 0000Z 31 September 2009
    cycle1=WorkflowMgr::CycleCron.new("0 0 31 9 * *","test")
    reftime=Time.gm(2009,9,30,15,43)
    nextcycle=cycle1.next(reftime)
    assert_equal(Time.gm(2009,10,1,0,0),nextcycle, message="tests input of wrong month/day combination; \
next cycle from 0000Z 31 September 2009")

    # tests next cycle from 1543Z 28 March 2007; specific hours; partial d-o-m; specific month
    #   00Z/12Z, Feb 01-15 of every year; every day
    cycle1=WorkflowMgr::CycleCron.new("0 0,12 1-15 2 * *","test")
    reftime=Time.gm(2007,3,28,15,43)
    nextcycle=cycle1.next(reftime)
    assert_equal(Time.gm(2008,2,1,0,0),nextcycle, message="tests next cycle from 1543Z 28 March 2007; \
specific hours; partial d-o-m; specific month\n   00Z/12Z, Feb 01-15 of every year; every day")

    # tests next cycle from 1543Z 28 March 2009; specific hours; partial d-o-m; leap year, specific month
    #   00Z/12Z, Feb 29 of every year; every day
    cycle1=WorkflowMgr::CycleCron.new("0 0,12 29-31 2 * *","test")
    reftime=Time.gm(2009,3,28,15,43)
    nextcycle=cycle1.next(reftime)
    assert_equal(Time.gm(2012,2,29,0,0),nextcycle, message="tests next cycle from 1543Z 28 March 2009; \
specific hours; partial d-o-m; leap year, specific month\n   00Z/12Z, Feb 29 of every year; every day")

    # tests next cycle from 1543Z Sat, 28 Feb 2009; both d-o-m and d-o-w set
    #   00Z/12Z, February 3-29 OR every Monday in February of every year 
    cycle1=WorkflowMgr::CycleCron.new("0 0,12 3-31 2 * 1","test")
    reftime=Time.gm(2009,2,28,15,43)
    nextcycle=cycle1.next(reftime)
    assert_equal(Time.gm(2010,2,1,0,0),nextcycle, message="tests next cycle from 1543Z Sat, 28 Feb 2009; \
both d-o-m and d-o-w set\n   00Z/12Z, February 3-29 OR every Monday in February of every year")

    # tests next cycle from 1543Z 28 Feb 2009; both d-o-m and d-o-w set
    #   00Z/12Z, February 3-29 OR every Saturday in February of every year 
    cycle1=WorkflowMgr::CycleCron.new("0 0,12 3-31 2 * 6","test")
    reftime=Time.gm(2009,2,28,15,43)
    nextcycle=cycle1.next(reftime)
    assert_equal(Time.gm(2010,2,3,0,0),nextcycle, message="tests next cycle from 1543Z 28 Feb 2009; \
both d-o-m and d-o-w set\n   00Z/12Z, February 3-29 OR every Saturday in February of every year")

    # tests next cycle from 1543Z 31 August 2010; specific hour; specific months; specific year
    #   12Z, every day of June, July, August of 2010
    cycle1=WorkflowMgr::CycleCron.new("0 12 * 6-8 2010 *","test")
    reftime=Time.gm(2010,8,31,15,43)
    nextcycle=cycle1.next(reftime)
    assert_nil(nextcycle, message="tests next cycle from 1543Z 31 August 2010; specific hour; specific months; \
specific year\n   12Z, every day of June, July, August of 2010")

    # tests next cycle from 2343Z 31 August 2010; all hours, specific months; specific year
    #   12Z, every day of June, July, August of 2010
    cycle1=WorkflowMgr::CycleCron.new("0 * * 6-8 2010 *","test")
    reftime=Time.gm(2010,8,31,23,43)
    nextcycle=cycle1.next(reftime)
    assert_nil(nextcycle, message="tests next cycle from 2343Z 31 August 2010; all hours, specific months; \
    specific year\n   12Z, every day of June, July, August of 2010")

  end

####  def test_cyclecron_next_previous
####
####    # tests now
####    cycle1=WorkflowMgr::CycleCron.new("test",["*","*","*","*","*","*"])
####    reftime=Time.at(Time.now.to_i)
####    reftime -= reftime.sec
####    nextcycle=cycle1.next(reftime)
####    assert_equal(reftime,nextcycle)
####    prevcycle=cycle1.previous(nextcycle)
####    assert_equal(prevcycle,reftime)
####
####  end

  def test_cyclecron_previous

    cycle1=WorkflowMgr::CycleCron.new("* * * * * *","test")
    reftime=Time.at(Time.now.to_i)
    reftime -= reftime.sec
    prevcycle=cycle1.previous(reftime)
    assert_equal(reftime,prevcycle)

    cycle1=WorkflowMgr::CycleCron.new("0 0 * * * *","test")
    reftime=Time.gm(2011,1,1,0,0)
    nextcycle=cycle1.previous(reftime)
    assert_equal(Time.gm(2011,1,1,0,0),nextcycle)

    # tests previous cycle; 12Z, leap year day, every month, every year
    cycle1=WorkflowMgr::CycleCron.new("0 12 * * * *","test")
    reftime=Time.gm(2008,3,1,0,0)
    prevcycle=cycle1.previous(reftime)
    assert_equal(Time.gm(2008,2,29,12,0),prevcycle, 
                 message="tests previous cycle; 12Z, leap year day, every month, every year")

    # tests previous cycle; 12Z, every day, every month, every year
    cycle1=WorkflowMgr::CycleCron.new("0 12 * * * *","test")
    reftime=Time.gm(2011,3,1,0,0)
    prevcycle=cycle1.previous(reftime)
    assert_equal(Time.gm(2011,2,28,12,0),prevcycle)

    # tests previous cycle from 0000Z 01 Feb 2010; both d-o-m and d-o-w set
    #   00Z/12Z, February 3-29 OR every Monday in February of every year 
    cycle1=WorkflowMgr::CycleCron.new("0 12 3-31 2 * 1","test")
    reftime=Time.gm(2010,2,1,0,0)
    prevcycle=cycle1.previous(reftime)
    assert_equal(Time.gm(2009,2,28,12,0),prevcycle)

  end

  def test_cyclecron_member

    cycle1=WorkflowMgr::CycleCron.new("* * * * * *","test")
    assert_equal(true,cycle1.member?(Time.now))

    cycle1=WorkflowMgr::CycleCron.new("* * * * 1970 *","test")
    assert_equal(false,cycle1.member?(Time.now))

    cycle1=WorkflowMgr::CycleCron.new("* * * * 2011 2-5","test")
    assert_equal(true,cycle1.member?(Time.gm(2011,8,30)))

    cycle1=WorkflowMgr::CycleCron.new("* * * * 2011 2-5","test")
    assert_equal(false,cycle1.member?(Time.gm(2011,8,29)))

    cycle1=WorkflowMgr::CycleCron.new("* * 10-15 * 2011 2-5","test")
    assert_equal(true,cycle1.member?(Time.gm(2011,8,15)))

    cycle1=WorkflowMgr::CycleCron.new("* * 10-15 * 2011 2-5","test")
    assert_equal(true,cycle1.member?(Time.gm(2011,8,30)))

    cycle1=WorkflowMgr::CycleCron.new("* * 10-15 * 2011 2-5","test")
    assert_equal(false,cycle1.member?(Time.gm(2011,8,1)))

  end

  def test_cycleinterval_init

    cycle1=WorkflowMgr::CycleInterval.new("201101010000 201201010000 1:00:00:00","test")
    cycle1=WorkflowMgr::CycleInterval.new("201101010000 201201010000 1:00:00","test")
    cycle1=WorkflowMgr::CycleInterval.new("201101010000 201201010000 1:00","test")

  end

  def test_cycleinterval_first

    cycle1=WorkflowMgr::CycleInterval.new("201101010000 201201010000 1:00:00:00","test")
    assert_equal(Time.gm(2011,1,1,0),cycle1.first)
    cycle1=WorkflowMgr::CycleInterval.new("201101010000 201201010000 1:00:00","test")
    assert_equal(Time.gm(2011,1,1,0),cycle1.first)
    cycle1=WorkflowMgr::CycleInterval.new("201101010000 201201010000 1:00","test")
    assert_equal(Time.gm(2011,1,1,0),cycle1.first)

  end

  def test_cycleinterval_next

    cycle1=WorkflowMgr::CycleInterval.new("201101010000 201201010000 1:00:00:00","test")

    cycle2=cycle1.next(cycle1.first)
    assert_equal(Time.gm(2011,1,1,0),cycle2)

    cycle2=cycle1.next(cycle1.first+1)
    assert_equal(Time.gm(2011,1,2,0),cycle2)

    cycle2=cycle1.next(cycle1.first-1)
    assert_equal(Time.gm(2011,1,1,0),cycle2)

    cycle1=WorkflowMgr::CycleInterval.new("201101010000 201201010000 1:00:00","test")

    cycle2=cycle1.next(cycle1.first)
    assert_equal(Time.gm(2011,1,1,0),cycle2)

    cycle2=cycle1.next(cycle1.first+1)
    assert_equal(Time.gm(2011,1,1,1),cycle2)

    cycle2=cycle1.next(cycle1.first-1)
    assert_equal(Time.gm(2011,1,1,0),cycle2)

    cycle1=WorkflowMgr::CycleInterval.new("201101010000 201201010000 1:00","test")

    cycle2=cycle1.next(cycle1.first)
    assert_equal(Time.gm(2011,1,1,0,0),cycle2)

    cycle2=cycle1.next(cycle1.first+1)
    assert_equal(Time.gm(2011,1,1,0,1),cycle2)

    cycle2=cycle1.next(cycle1.first-1)
    assert_equal(Time.gm(2011,1,1,0,0),cycle2)

  end


  def test_cycleinterval_previous

    cycle1=WorkflowMgr::CycleInterval.new("201101010000 201201010000 1:00:00:00","test")

    cycle2=cycle1.previous(Time.gm(2011,3,1,0,0,0))
    assert_equal(Time.gm(2011,3,1,0),cycle2)

    cycle2=cycle1.previous(Time.gm(2011,3,1,0,0,0)+1)
    assert_equal(Time.gm(2011,3,1,0),cycle2)

    cycle2=cycle1.previous(Time.gm(2011,3,1,0,0,0)-1)
    assert_equal(Time.gm(2011,2,28,0),cycle2)

    cycle1=WorkflowMgr::CycleInterval.new("201101010000 201201010000 1:00:00","test")

    cycle2=cycle1.previous(Time.gm(2011,3,1,0,0,0))
    assert_equal(Time.gm(2011,3,1,0),cycle2)

    cycle2=cycle1.previous(Time.gm(2011,3,1,0,0,0)+1)
    assert_equal(Time.gm(2011,3,1,0),cycle2)

    cycle2=cycle1.previous(Time.gm(2011,3,1,0,0,0)-1)
    assert_equal(Time.gm(2011,2,28,23),cycle2)

    cycle1=WorkflowMgr::CycleInterval.new("201101010000 201201010000 1:00","test")

    cycle2=cycle1.previous(Time.gm(2011,3,1,0,0,0))
    assert_equal(Time.gm(2011,3,1,0,0),cycle2)

    cycle2=cycle1.previous(Time.gm(2011,3,1,0,0,0)+1)
    assert_equal(Time.gm(2011,3,1,0,0),cycle2)

    cycle2=cycle1.previous(Time.gm(2011,3,1,0,0,0)-1)
    assert_equal(Time.gm(2011,2,28,23,59),cycle2)

  end


  def test_cycleinterval_member

    cycle1=WorkflowMgr::CycleInterval.new("201101010000 201201010000 1:00:00:00","test")
    assert_equal(false,cycle1.member?(Time.gm(1970,1,1)))

    cycle1=WorkflowMgr::CycleInterval.new("201101010000 201201010000 1:00:00:00","test")
    assert_equal(false,cycle1.member?(Time.gm(2100,1,1)))

    cycle1=WorkflowMgr::CycleInterval.new("201101010000 201201010000 1:00:00:00","test")
    assert_equal(true,cycle1.member?(Time.gm(2011,8,1)))

    cycle1=WorkflowMgr::CycleInterval.new("201101010000 201201010000 2:00:00:00","test")
    assert_equal(false,cycle1.member?(Time.gm(2011,1,2)))

    cycle1=WorkflowMgr::CycleInterval.new("201101010000 201201010000 2:00:00:00","test")
    assert_equal(true,cycle1.member?(Time.gm(2011,1,3)))

  end

end
