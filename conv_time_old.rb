#! /usr/local/bin/ruby
# coding: utf-8
#=各種時刻換算
#
# date          name            version
# 2016.03.22    mk-mode         1.00 新規作成
# 2016.05.12    mk-mode         1.01 UPD: Fixed jst_to_utc method.
# 2016.07.27    mk-mode         1.02 UPD: Changed a class name. (ConvTime -> ConvTimeOld)
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
#   - 2015年07月01日以降は一律で 36
#   - その他は、指定の値
#     [うるう秒実施日一覧](http://jjy.nict.go.jp/QandA/data/leapsec.html)
# * ΔT = TT - UT1 は、以下のとおりとする。
#   - 1972-01-01 以降、うるう秒挿入済みの年+αまでは、以下で算出
#       ΔT = 32.184 - (UTC - TAI)
#     UTC - TAI は [うるう秒実施日一覧](http://jjy.nict.go.jp/QandA/data/leapsec.html) を参照
#   - その他の期間は NASA 提供の略算式により算出
#     [NASA - Polynomial Expressions for Delta T](http://eclipse.gsfc.nasa.gov/SEhelp/deltatpoly2004.html)
#---------------------------------------------------------------------------------
require 'date'

class ConvTimeOld
  JST_UTC = 9
  DUT1    = 0.0  # = UT1 - UTC
  TT_TAI  = 32.184
  L_G     = 6.969290134 * 10**(-10)
  L_B     = 1.550519768 * 10**(-8)
  T_0     = 2443144.5003725
  TDB_0   = -6.55 * 10**(-5)
  MSG_ERR = "[ERROR] Format: YYYYMMDD or YYYYMMDDHHMMSS"

  def initialize
    jst = Time.now
    @year  = jst.year
    @month = jst.month
    @day   = jst.day
    @hour  = jst.hour
    @min   = jst.min
    @sec   = jst.sec
    @jst = Time.new(@year, @month, @day, @hour, @min, @sec).to_f
    get_arg  # 引数取得
  end

  def exec
    begin
      jst_to_utc      # JST -> UTC
      @jd = gc_to_jd(
        @year, @month, @day, @hour, @min, @sec
      )               # ユリウス日
      calc_ut1        # UT1
      calc_tai        # TAI
      calc_delta_t    # ΔT
      calc_tt         # TT
      calc_tcg        # TCG
      calc_tcb        # TCB
      t_tcb = Time.at(@tcb)
      @jd_tcb = gc_to_jd(
        t_tcb.year, t_tcb.month, t_tcb.day,
        t_tcb.hour, t_tcb.min, t_tcb.sec
      )               # ユリウス日(TCB)
      calc_tdb        # TDB
      display         # 結果出力
    rescue => e
      $stderr.puts "[#{e.class}] #{e.message}\n"
      e.backtrace.each { |tr| $stderr.puts "\t#{tr}" }
    end
  end

  private

  #=========================================================================
  # 引数取得
  #
  #   * コマンドライン引数を取得して日時の妥当性チェックを行う
  #=========================================================================
  def get_arg
    return unless arg = ARGV.shift
    (puts MSG_ERR; exit 0) unless arg =~ /^\d{8}$|^\d{14}$/
    @year, @month, @day = arg[ 0, 4].to_i, arg[ 4, 2].to_i, arg[ 6, 2].to_i
    @hour, @min,   @sec = arg[ 8, 2].to_i, arg[10, 2].to_i, arg[12, 2].to_i
    (puts MSG_ERR; exit 0) unless Date.valid_date?(@year, @month, @day)
    (puts MSG_ERR; exit 0) if @hour > 23 || @min > 59 || @sec > 59
    @jst = Time.new(@year, @month, @day, @hour, @min, @sec).to_f
  rescue => e
    raise
  end

  #=========================================================================
  # JST -> UTC
  #
  #   * UTC = JST - 9
  #=========================================================================
  def jst_to_utc
    @utc = @jst - JST_UTC * 60 * 60
    tm_utc = Time.at(@utc)
    @year  = tm_utc.year
    @month = tm_utc.month
    @day   = tm_utc.day
    @hour  = tm_utc.hour
    @min   = tm_utc.min
    @sec   = tm_utc.sec
  rescue => e
    raise
  end

  #=========================================================================
  # 年月日(グレゴリオ暦)からユリウス日(JD)を計算する
  #
  #   * フリーゲルの公式を使用する
  #       JD = int(365.25 * year)
  #          + int(year / 400)
  #          - int(year / 100)
  #          + int(30.59 * (month - 2))
  #          + day
  #          + 1721088
  #   ※上記の int(x) は厳密には、x を超えない最大の整数
  #     (ちなみに、準JDを求めるなら `+ 1721088` が `- 678912` となる)
  #=========================================================================
  def gc_to_jd(year, month, day, hour, min, sec)
    # 1月,2月は前年の13月,14月とする
    if month < 3
      year  -= 1
      month += 12
    end
    # 日付(整数)部分計算
    jd  = (365.25 * year).truncate
    jd += (year / 400.0).truncate
    jd -= (year / 100.0).truncate
    jd += (30.59 * (month - 2)).truncate
    jd += day
    jd += 1721088.5
    # 時間(小数)部分計算
    t  = sec / 3600.0
    t += min / 60.0
    t += hour
    t  = t / 24.0
    return jd + t
  rescue => e
    raise
  end

  #=========================================================================
  # UT1
  #
  #   * UT1 = UTC + DUT1
  #=========================================================================
  def calc_ut1
    @ut1 = @utc + DUT1
  rescue => e
    raise
  end

  #=========================================================================
  # TAI
  #
  #   * TAI = UTC - UTC_TAI
  #     但し、UTC_TAI（協定世界時と国際原子時の差）は、以下のとおりとする。
  #     - 1972年07月01日より古い場合は一律で -10
  #     - 2015年07月01日以降は一律で -36
  #     - その他は、指定の値
  #       [うるう秒実施日一覧](http://jjy.nict.go.jp/QandA/data/leapsec.html)
  #=========================================================================
  def calc_tai
    ymd = sprintf("%04d-%02d-%02d", @year, @month, @day)
    case
    when ymd < "1972-07-01"; @utc_tai = -10
    when ymd < "1973-01-01"; @utc_tai = -11
    when ymd < "1974-01-01"; @utc_tai = -12
    when ymd < "1975-01-01"; @utc_tai = -13
    when ymd < "1976-01-01"; @utc_tai = -14
    when ymd < "1977-01-01"; @utc_tai = -15
    when ymd < "1978-01-01"; @utc_tai = -16
    when ymd < "1979-01-01"; @utc_tai = -17
    when ymd < "1980-01-01"; @utc_tai = -18
    when ymd < "1981-07-01"; @utc_tai = -19
    when ymd < "1982-07-01"; @utc_tai = -20
    when ymd < "1983-07-01"; @utc_tai = -21
    when ymd < "1985-07-01"; @utc_tai = -22
    when ymd < "1988-01-01"; @utc_tai = -23
    when ymd < "1990-01-01"; @utc_tai = -24
    when ymd < "1991-01-01"; @utc_tai = -25
    when ymd < "1992-07-01"; @utc_tai = -26
    when ymd < "1993-07-01"; @utc_tai = -27
    when ymd < "1994-07-01"; @utc_tai = -28
    when ymd < "1996-01-01"; @utc_tai = -29
    when ymd < "1997-07-01"; @utc_tai = -30
    when ymd < "1999-01-01"; @utc_tai = -31
    when ymd < "2006-01-01"; @utc_tai = -32
    when ymd < "2009-01-01"; @utc_tai = -33
    when ymd < "2012-07-01"; @utc_tai = -34
    when ymd < "2015-07-01"; @utc_tai = -35
    else;                    @utc_tai = -36  # <= 次回うるう秒実施までの暫定措置
    end
    @tai = @utc - @utc_tai
  rescue => e
    raise
  end

  #=========================================================================
  # TT
  #
  #   * TT = TAI + TT_TAI
  #        = UT1 + ΔT
  #=========================================================================
  def calc_tt
    #@tt = @tai + TT_TAI
    @tt = @ut1 + @delta_t
  rescue => e
    raise
  end

  #=========================================================================
  # TCG
  #
  #   * TCG = TT + L_G * (JD - T_0) * 86,400
  #     （JD: ユリウス日,
  #       L_G = 6.969290134 * 10^(-10), T_0 = 2,443,144.5003725）
  #=========================================================================
  def calc_tcg
    @tcg = @tt + L_G * (@jd - T_0) * 86400
  rescue => e
    raise
  end

  #=========================================================================
  # TDB
  #
  #   * TDB = TCB - L_B * (JD_TCB - T_0) * 86400 + TDB_0
  #=========================================================================
  def calc_tdb
    @tdb = @tcb - L_B * (@jd_tcb - T_0) * 86400 + TDB_0
  rescue => e
    raise
  end

  #=========================================================================
  # TCB
  #
  #   * TCB = TT + L_B * (JD - T_0) * 86400
  #=========================================================================
  def calc_tcb
    @tcb = @tt + L_B * (@jd - T_0) * 86400
  rescue => e
    raise
  end

  #=========================================================================
  # ΔT
  #
  #   * ΔT = TT - UT1
  #     但し、
  #     - 1972-01-01 以降、うるう秒挿入済みの年+αまでは、以下で算出
  #         ΔT = 32.184 - (UTC - TAI)
  #       UTC - TAI は [うるう秒実施日一覧](http://jjy.nict.go.jp/QandA/data/leapsec.html) を参照
  #     - その他の期間は NASA 提供の略算式により算出
  #       [NASA - Polynomial Expressions for Delta T](http://eclipse.gsfc.nasa.gov/SEhelp/deltatpoly2004.html)
  #=========================================================================
  def calc_delta_t
    ymd = sprintf("%04d-%02d-%02d", @year, @month, @day)
    case
    when @year < -500
      t = (@year-1820) / 100.0
      dt  = -20
      dt += 32 * t ** 2
    when -500 <= @year && @year < 500
      t = @year / 100.0
      dt  = 10583.6
      dt -= 1014.41 * t
      dt += 33.78311 * t ** 2
      dt -= 5.952053 * t ** 3
      dt -= 0.1798452 * t ** 4
      dt += 0.022174192 * t ** 5
      dt += 0.0090316521 * t ** 6
    when 500 <= @year && @year < 1600
      t = (year - 1000) / 100.0
      dt  = 1574.2
      dt -= 556.01 * t
      dt += 71.23472 * t ** 2
      dt += 0.319781 * t ** 3
      dt -= 0.8503463 * t ** 4
      dt -= 0.005050998 * t ** 5
      dt += 0.0083572073 * t ** 6
    when 1600 <= @year && @year < 1700
      t = @year - 1600
      dt  = 120
      dt -= 0.9808 * t
      dt -= 0.01532 * t ** 2
      dt += t ** 3 / 7129.0
    when 1700 <= @year && @year < 1800
      t = @year - 1700
      dt  = 8.83
      dt += 0.1603 * t
      dt -= 0.0059285 * t ** 2
      dt += 0.00013336 * t ** 3
      dt -= t ** 4 / 1174000.0
    when 1800 <= @year && @year < 1860
      t = @year - 1800
      dt  = 13.72
      dt -= 0.332447 * t
      dt += 0.0068612 * t ** 2
      dt += 0.0041116 * t ** 3
      dt -= 0.00037436 * t ** 4
      dt += 0.0000121272 * t ** 5
      dt -= 0.0000001699 * t ** 6
      dt += 0.000000000875 * t ** 7
    when 1860 <= @year && @year < 1900
      t = @year - 1860
      dt  = 7.62
      dt += 0.5737 * t
      dt -= 0.251754 * t ** 2
      dt += 0.01680668 * t ** 3
      dt -= 0.0004473624 * t ** 4
      dt += t ** 5 / 233174.0
    when 1900 <= @year && @year < 1920
      t = @year - 1900
      dt  = -2.79
      dt += 1.494119 * t
      dt -= 0.0598939 * t ** 2
      dt += 0.0061966 * t ** 3
      dt -= 0.000197 * t ** 4
    when 1920 <= @year && @year < 1941
      t = @year - 1920
      dt  = 21.20
      dt += 0.84493 * t
      dt -= 0.076100 * t ** 2
      dt += 0.0020936 * t ** 3
    when 1941 <= @year && @year < 1961
      t = @year - 1950
      dt  = 29.07
      dt += 0.407 * t
      dt -= t ** 2 / 233.0
      dt += t ** 3 / 2547.0
    when 1961 <= @year && @year < 1986
      case
      when ymd < sprintf("%04d-%02d-%02d", 1972, 1, 1)
        t = @year - 1975
        dt  = 45.45
        dt += 1.067 * t
        dt -= t ** 2 / 260.0
        dt -= t ** 3 / 718.0
      when ymd < "1972-07-01"; dt = TT_TAI + 10
      when ymd < "1973-01-01"; dt = TT_TAI + 11
      when ymd < "1974-01-01"; dt = TT_TAI + 12
      when ymd < "1975-01-01"; dt = TT_TAI + 13
      when ymd < "1976-01-01"; dt = TT_TAI + 14
      when ymd < "1977-01-01"; dt = TT_TAI + 15
      when ymd < "1978-01-01"; dt = TT_TAI + 16
      when ymd < "1979-01-01"; dt = TT_TAI + 17
      when ymd < "1980-01-01"; dt = TT_TAI + 18
      when ymd < "1981-07-01"; dt = TT_TAI + 19
      when ymd < "1982-07-01"; dt = TT_TAI + 20
      when ymd < "1983-07-01"; dt = TT_TAI + 21
      when ymd < "1985-07-01"; dt = TT_TAI + 22
      when ymd < "1988-01-01"; dt = TT_TAI + 23
      end
    when 1986 <= @year && @year < 2005
      # t = @year - 2000
      # dt  = 63.86
      # dt += 0.3345 * t
      # dt -= 0.060374 * t ** 2
      # dt += 0.0017275 * t ** 3
      # dt += 0.000651814 * t ** 4
      # dt += 0.00002373599 * t ** 5
      case
      when ymd < "1988-01-01"; dt = TT_TAI + 23
      when ymd < "1990-01-01"; dt = TT_TAI + 24
      when ymd < "1991-01-01"; dt = TT_TAI + 25
      when ymd < "1992-07-01"; dt = TT_TAI + 26
      when ymd < "1993-07-01"; dt = TT_TAI + 27
      when ymd < "1994-07-01"; dt = TT_TAI + 28
      when ymd < "1996-01-01"; dt = TT_TAI + 29
      when ymd < "1997-07-01"; dt = TT_TAI + 30
      when ymd < "1999-01-01"; dt = TT_TAI + 31
      when ymd < "2006-01-01"; dt = TT_TAI + 32
      end
    when 2005 <= @year && @year < 2050
      case
      when ymd < "2006-01-01"; dt = TT_TAI + 32
      when ymd < "2009-01-01"; dt = TT_TAI + 33
      when ymd < "2012-07-01"; dt = TT_TAI + 34
      when ymd < "2015-07-01"; dt = TT_TAI + 35
      when ymd < "2017-07-01"; dt = TT_TAI + 36  # <= 次回うるう秒実施までの暫定措置
      else
        t = @year - 2000
        dt  = 62.92
        dt += 0.32217 * t
        dt += 0.005589 * t ** 2
      end
    when 2050 <= @year && @year <= 2150
      dt  = -20
      dt += 32 * ((@year - 1820)/100.0) ** 2
      dt -= 0.5628 * (2150 - @year)
    when 2150 < @year
      t = (@year-1820)/100
      dt  = -20
      dt += 32 * t ** 2
    end
    @delta_t = dt
  rescue => e
    raise
  end

  def display
    str =  "      JST: #{Time.at(@jst).strftime("%Y-%m-%d %H:%M:%S.%3N")}\n"
    str << "      UTC: #{Time.at(@utc).strftime("%Y-%m-%d %H:%M:%S.%3N")}\n"
    str << "JST - UTC: #{JST_UTC}\n"
    str << sprintf("       JD: %.10f day\n", @jd)
    str << sprintf("     DUT1: %.1f sec\n", DUT1)
    str << "      UT1: #{Time.at(@ut1).strftime("%Y-%m-%d %H:%M:%S.%3N")}\n"
    str << "UTC - TAI: #{@utc_tai} sec\n"
    str << "      TAI: #{Time.at(@tai).strftime("%Y-%m-%d %H:%M:%S.%3N")}\n"
    str << sprintf(" TT - TAI: %.3f sec\n", TT_TAI)
    str << "       TT: #{Time.at(@tt).strftime("%Y-%m-%d %H:%M:%S.%3N")}\n"
    str << sprintf("  delta T: %.3f sec\n", @delta_t)
    str << "      TCG: #{Time.at(@tcg).strftime("%Y-%m-%d %H:%M:%S.%3N")}\n"
    str << "      TCB: #{Time.at(@tcb).strftime("%Y-%m-%d %H:%M:%S.%3N")}\n"
    str << sprintf("   JD_TCB: %.10f day\n", @jd_tcb)
    str << "      TDB: #{Time.at(@tdb).strftime("%Y-%m-%d %H:%M:%S.%3N")}"
    puts str
  rescue => e
    raise
  end
end

ConvTimeOld.new.exec

