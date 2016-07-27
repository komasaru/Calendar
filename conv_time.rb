#! /usr/local/bin/ruby
# coding: utf-8
#= 各種時刻換算
#  : 自作 RubyGems ライブラリ mk_time 使用版
#
# date          name            version
# 2016.07.27    mk-mode         1.00 新規作成
#
# Copyright(C) 2016 mk-mode.com All Rights Reserved.
#---------------------------------------------------------------------------------
# 引数 : JST（日本標準時）
#          書式：YYYYMMDD or YYYYMMDDHHMMSS
#          無指定なら現在(システム日時)と判断。
#---------------------------------------------------------------------------------
# * 定数 DUT1 (= UT1 - UTC) の値は以下を参照。
#     [日本標準時プロジェクト Announcement of DUT1](http://jjy.nict.go.jp/QandA/data/dut1.html)
#   但し、値は 1.0 秒以下なので、精度を問わないなら 0.0 固定でもよい(?)
# * UTC - TAI（協定世界時と国際原子時の差）は、以下のとおりとする。
#   - 1972年07月01日より古い場合は一律で 10
#   - 2019年07月01日以降は一律で 37
#   - その他は、指定の値
#     [日本標準時プロジェクト　Information of Leap second](http://jjy.nict.go.jp/QandA/data/leapsec.html)
# * ΔT = TT - UT1 は、以下のとおりとする。
#   - 1972-01-01 以降、うるう秒挿入済みの年+2までは、以下で算出
#       ΔT = 32.184 - (UTC - TAI) - DUT1
#     UTC - TAI は [うるう秒実施日一覧](http://jjy.nict.go.jp/QandA/data/leapsec.html) を参照
#   - その他の期間は NASA 提供の略算式により算出
#     [NASA - Polynomial Expressions for Delta T](http://eclipse.gsfc.nasa.gov/SEcat5/deltatpoly.html)
#---------------------------------------------------------------------------------
require 'date'
require 'mk_time'

class ConvTime
  MSG_ERR = "[ERROR] Format: YYYYMMDD or YYYYMMDDHHMMSS"
  JST_UTC = 9

  def initialize
    @jst = get_arg
    @utc = jst2utc(@jst)
  end

  def exec
    t = MkTime.new(@utc.strftime("%Y%m%d%H%M%S"))
    display(t)
  rescue => e
    $stderr.puts "[#{e.class}] #{e.message}\n"
    e.backtrace.each { |tr| $stderr.puts "\t#{tr}" }
  end

  private

  #=========================================================================
  # 引数取得
  #
  #   * コマンドライン引数を取得して日時の妥当性チェックを行う
  #=========================================================================
  def get_arg
    return Time.now unless arg = ARGV.shift
    (puts MSG_ERR; exit 0) unless arg =~ /^\d{8}$|^\d{14}$/
    year, month, day = arg[ 0, 4].to_i, arg[ 4, 2].to_i, arg[ 6, 2].to_i
    hour, min,   sec = arg[ 8, 2].to_i, arg[10, 2].to_i, arg[12, 2].to_i
    (puts MSG_ERR; exit 0) unless Date.valid_date?(year, month, day)
    (puts MSG_ERR; exit 0) if hour > 23 || min > 59 || sec > 59
    return Time.new(year, month, day, hour, min, sec)
  rescue => e
    raise
  end

  #=========================================================================
  # JST -> UTC
  #
  # * UTC = JST - 9
  #
  # @param:  jst  (Time Object)
  # @return: utc  (Time Object)
  #=========================================================================
  def jst2utc(jst)
    return Time.at(jst - JST_UTC * 60 * 60)
  rescue => e
    raise
  end

  #=========================================================================
  # 結果出力
  #
  # @param:  t  (MkTime Object)
  # @return: <none>
  #=========================================================================
  def display(t)
    puts "      JST: #{Time.at(t.jst).strftime("%Y-%m-%d %H:%M:%S")}"
    puts "      UTC: #{Time.at(t.utc).strftime("%Y-%m-%d %H:%M:%S")}"
    puts "JST - UTC: #{JST_UTC}"
    puts sprintf("       JD: %.10f day", t.jd)
    puts sprintf("        T: %.10f century (= Julian Century Number)", t.t)
    puts "UTC - TAI: #{t.utc_tai} sec (= amount of leap seconds)"
    puts sprintf("     DUT1: %.1f sec", t.dut1)
    puts sprintf("  delta T: %.3f sec", t.dt)
    puts "      TAI: #{t.tai.instance_eval { '%s.%03d' % [strftime('%Y-%m-%d %H:%M:%S'), (usec / 1000.0).round]}}"
    puts "      UT1: #{t.ut1.instance_eval { '%s.%03d' % [strftime('%Y-%m-%d %H:%M:%S'), (usec / 1000.0).round]}}"
    puts "       TT: #{t.tt .instance_eval { '%s.%03d' % [strftime('%Y-%m-%d %H:%M:%S'), (usec / 1000.0).round]}}"
    puts "      TCG: #{t.tcg.instance_eval { '%s.%03d' % [strftime('%Y-%m-%d %H:%M:%S'), (usec / 1000.0).round]}}"
    puts "      TCB: #{t.tcb.instance_eval { '%s.%03d' % [strftime('%Y-%m-%d %H:%M:%S'), (usec / 1000.0).round]}}"
    puts "      TDB: #{t.tdb.instance_eval { '%s.%03d' % [strftime('%Y-%m-%d %H:%M:%S'), (usec / 1000.0).round]}}"
  rescue => e
    raise
  end
end


ConvTime.new.exec

