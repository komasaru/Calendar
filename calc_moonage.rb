#! /usr/local/bin/ruby
# coding: utf-8
#=月齢計算スクリプト
# （グレゴリオ暦から月齢を計算する）
#
# date          name            version
# 2013.02.19    mk-mode         1.00 新規作成
# 2013.03.20    mk-mode         1.01 補正値計算処理を追加
# 2016.03.03    mk-mode         1.02 地球自転遅れ補正値ΔTの計算機能を追加
#                                    Ref: [NASA - Polynomial Expressions for Delta T](http://eclipse.gsfc.nasa.gov/SEhelp/deltatpoly2004.html)
# 2016.03.07    mk-mode         1.03 うるう秒挿入が明確な場合の処理を追加
#
# Copyright(C) 2013-2016 mk-mode.com All Rights Reserved.
#---------------------------------------------------------------------------------
# 引数 : 計算日時(グレゴリオ暦)
#          書式：YYYYMMDD or YYYYMMDDHHMMSS
#          無指定なら現在(システム日時)と判断。
#---------------------------------------------------------------------------------
require 'date'

# 円周率の定義
PI = 3.141592653589793238462
# （角度の）度からラジアンに変換する係数の定義
K = PI / 180.0
# UTC ( +9 )
UTC = 9

#============
# 計算クラス
#============
class CalcMoonage
  def initialize(dt)
    # 年月日時分秒
    @year  = dt[ 0, 4].to_i
    @month = dt[ 4, 2].to_i
    @day   = dt[ 6, 2].to_i
    @hour  = dt[ 8, 2].to_i
    @min   = dt[10, 2].to_i
    @sec   = dt[12, 2].to_i
  end

  #=========================================================================
  # 年月日(グレゴリオ暦)からユリウス日(JD)を計算する
  #
  #   フリーゲルの公式を使用する
  #   [ JD ] = int( 365.25 × year )
  #          + int( year / 400 )
  #          - int( year / 100 )
  #          + int( 30.59 ( month - 2 ) )
  #          + day
  #          + 1721088
  #   ※上記の int( x ) は厳密には、x を超えない最大の整数
  #     ( ちなみに、[ 準JD ]を求めるなら + 1721088 が - 678912 となる )
  #=========================================================================
  def gc_to_jd
    begin
      # 1月,2月は前年の13月,14月とする
      if @month < 3
        @year -= 1
        @month += 12
      end

      # 日付(整数)部分計算
      @jd  = (365.25 * @year).truncate
      @jd += (@year / 400.0).truncate
      @jd -= (@year / 100.0).truncate
      @jd += (30.59 * (@month - 2)).truncate
      @jd += @day
      @jd += 1721088

      # 時間(小数)部分計算
      t  = @sec / 3600.0
      t += @min / 60.0
      t += @hour
      t  = t / 24.0

      @jd += t
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".gc_to_jd] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # ユリウス通日の直近の朔の時刻（JST）を求める
  #=========================================================================
  def calc_saku
    begin
      # LOOPカウンタのリセット
      lc=1

      # 時刻引数を分解する
      tm1 = @jd.truncate
      tm2 = @jd - tm1
      # JST ==> DT ( 補正時刻=0.0sec と仮定して計算 )
      tm2 -= 9 / 24.0

      # 繰り返し計算によって朔の時刻を計算する
      # (誤差が±1.0 sec以内になったら打ち切る。)
      delta_t1 = 0 ; delta_t2 = 1
      while (delta_t1 + delta_t2).abs > (1.0 / 86400.0)
        # 太陽の黄経λsun ,月の黄経λmoon を計算
        t  = (tm2 + 0.5) / 36525.0
        t += (tm1 - 2451545) / 36525.0
        rm_sun  = calc_longitude_sun(t)
        rm_moon = calc_longitude_moon(t)

        # 月と太陽の黄経差Δλ
        # Δλ＝λmoon－λsun
        delta_rm = rm_moon - rm_sun

        # ﾙｰﾌﾟの1回目 ( lc = 1 ) で delta_rm < 0.0 の場合には引き込み範囲に
        # 入るように補正する
        if lc == 1 && delta_rm < 0
          delta_rm = normalize_angle(delta_rm)
        #   春分の近くで朔がある場合 ( 0 ≦λsun≦ 20 ) で、月の黄経λmoon≧300 の
        #   場合には、Δλ＝ 360.0 － Δλ と計算して補正する
        elsif rm_sun >= 0 && rm_sun <= 20 && rm_moon >= 300
        delta_rm = normalize_angle(delta_rm)
          delta_rm = 360 - delta_rm
        # Δλの引き込み範囲 ( ±40° ) を逸脱した場合には、補正を行う
        elsif delta_rm.abs > 40.0
          delta_rm = normalize_angle(delta_rm)
        end

        # 時刻引数の補正値 Δt
        # delta_t = delta_rm * 29.530589 / 360.0;
        delta_t1  = (delta_rm * 29.530589 / 360.0).truncate
        delta_t2  = delta_rm * 29.530589 / 360.0
        delta_t2 -= delta_t1;

        # 時刻引数の補正
        tm1 = tm1 - delta_t1
        tm2 = tm2 - delta_t2
        if tm2 < 0
          tm2 += 1
          tm1 -= 1
        end

        # ループ回数が15回になったら、初期値 tm を tm-26 とする。
        if lc == 15 && (delta_t1 + delta_t2).abs > (1.0 / 86400.0)
          tm1 = (@jd - 26).truncate
          tm2 = 0
        # 初期値を補正したにも関わらず、振動を続ける場合には初期値を答えとして
        # 返して強制的にループを抜け出して異常終了させる。
        elsif lc > 30 && (delta_t1+delta_t2).abs > (1.0 / 86400.0)
          tm1 = @jd
          tm2 = 0
          break
        end

        # LOOPカウンタインクリメント
        lc += 1
      end

      # 時刻引数を合成するのと、DT ==> JST 変換を行い、戻り値とする
      # （補正時刻=0.0sec と仮定して計算）
      @saku_last = tm2 + tm1 + 9 / 24.0
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".calc_saku] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # ユリウス通日の直近の朔の時刻（JST）を求める ( 補正 )
  #=========================================================================
  def calc_saku_new
    begin
      # LOOPカウンタのリセット
      lc = 1

      # 時刻引数を分解する
      jd = @jd - 0.5
      tm1 = jd.truncate
      tm2 = jd - tm1
      tm2 -= 9 / 24.0

      # 繰り返し計算によって朔の時刻を計算する
      # (誤差が±1.0 sec以内になったら打ち切る。)
      delta_t1 = 0 ; delta_t2 = 1
      while (delta_t1 + delta_t2).abs > (1.0 / 86400.0)
        # 太陽の黄経λsun ,月の黄経λmoon を計算
        t = tm1 + tm2 + 9 / 24.0
        rm_sun  = calc_longitude_sun_new(t)
        rm_moon = calc_longitude_moon_new(t)

        # 月と太陽の黄経差Δλ
        # Δλ＝λmoon－λsun
        delta_rm = rm_moon - rm_sun

        # ﾙｰﾌﾟの1回目 ( lc = 1 ) で delta_rm < 0.0 の場合には引き込み範囲に
        # 入るように補正する
        if lc == 1 && delta_rm < 0
          delta_rm = normalize_angle(delta_rm)
        #   春分の近くで朔がある場合 ( 0 ≦λsun≦ 20 ) で、月の黄経λmoon≧300 の
        #   場合には、Δλ＝ 360.0 － Δλ と計算して補正する
        elsif rm_sun >= 0 && rm_sun <= 20 && rm_moon >= 300
        delta_rm = normalize_angle(delta_rm)
          delta_rm = 360 - delta_rm
        # Δλの引き込み範囲 ( ±40° ) を逸脱した場合には、補正を行う
        elsif delta_rm.abs > 40.0
          delta_rm = normalize_angle(delta_rm)
        end

        # 時刻引数の補正値 Δt
        # delta_t = delta_rm * 29.530589 / 360.0;
        delta_t1  = (delta_rm * 29.530589 / 360.0).truncate
        delta_t2  = delta_rm * 29.530589 / 360.0
        delta_t2 -= delta_t1;

        # 時刻引数の補正
        tm1 = tm1 - delta_t1
        tm2 = tm2 - delta_t2
        if tm2 < 0
          tm2 += 1
          tm1 -= 1
        end

        # ループ回数が15回になったら、初期値 tm を tm-26 とする。
        if lc == 15 && (delta_t1 + delta_t2).abs > (1.0 / 86400.0)
          tm1 = (jd - 26).truncate
          tm2 = 0
        # 初期値を補正したにも関わらず、振動を続ける場合には初期値を答えとして
        # 返して強制的にループを抜け出して異常終了させる。
        elsif lc > 30 && (delta_t1+delta_t2).abs > (1.0 / 86400.0)
          tm1 = jd
          tm2 = 0
          break
        end

        # LOOPカウンタインクリメント
        lc += 1
      end

      # 時刻引数を合成
      @saku_last_new = tm2 + tm1 + 9 / 24.0
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".calc_saku_new] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # 月齢計算
  #=========================================================================
  def calc_moonage
    begin
      return @jd - @saku_last
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".calc_moonage] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # 月齢計算 ( 補正 )
  #=========================================================================
  def calc_moonage_new
    begin
      return @jd - @saku_last_new
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".calc_moonage_new] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # 太陽の黄経 λsun 計算
  #=========================================================================
  def calc_longitude_sun(t)
    begin
      # 摂動項の計算
      ang = normalize_angle( 31557.0 * t + 161.0)
      th  = 0.0004 * Math.cos(K * ang)
      ang = normalize_angle( 29930.0 * t +  48.0)
      th += 0.0004 * Math.cos(K * ang)
      ang = normalize_angle(  2281.0 * t + 221.0)
      th += 0.0005 * Math.cos(K * ang)
      ang = normalize_angle(   155.0 * t + 118.0)
      th += 0.0005 * Math.cos(K * ang)
      ang = normalize_angle( 33718.0 * t + 316.0)
      th += 0.0006 * Math.cos(K * ang)
      ang = normalize_angle(  9038.0 * t +  64.0)
      th += 0.0007 * Math.cos(K * ang)
      ang = normalize_angle(  3035.0 * t + 110.0)
      th += 0.0007 * Math.cos(K * ang)
      ang = normalize_angle( 65929.0 * t +  45.0)
      th += 0.0007 * Math.cos(K * ang)
      ang = normalize_angle( 22519.0 * t + 352.0)
      th += 0.0013 * Math.cos(K * ang)
      ang = normalize_angle( 45038.0 * t + 254.0)
      th += 0.0015 * Math.cos(K * ang)
      ang = normalize_angle(445267.0 * t + 208.0)
      th += 0.0018 * Math.cos(K * ang)
      ang = normalize_angle(    19.0 * t + 159.0)
      th += 0.0018 * Math.cos(K * ang)
      ang = normalize_angle( 32964.0 * t + 158.0)
      th += 0.0020 * Math.cos(K * ang)
      ang = normalize_angle( 71998.1 * t + 265.1)
      th += 0.0200 * Math.cos(K * ang)
      ang = normalize_angle(35999.05 * t + 267.52)
      th -= 0.0048 * t * Math.cos(K * ang)
      th += 1.9147     * Math.cos(K * ang)

      # 比例項の計算
      ang = normalize_angle(36000.7695 * t)
      ang = normalize_angle(ang + 280.4659)

      # 太陽黄経
      return normalize_angle(th + ang)
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".get_longitude_sun] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # 太陽の黄経 λsun 計算 ( 補正 )
  #=========================================================================
  def calc_longitude_sun_new(t)
    begin
      # ユリウス通日から年月日時分秒を計算
      ymdt = jd_to_ymdt(t)
      year  = ymdt[0]
      month = ymdt[1]
      day   = ymdt[2]
      hour  = ymdt[3]
      min   = ymdt[4]
      sec   = ymdt[5]

      # 時分秒から日計算
      t  = hour * 60 * 60
      t += min * 60
      t += sec
      t /= 86400.0

      # 地球自転遅れ補正値(日)計算
      #rotate_rev = (57 + 0.8 * (year - 1990)) / 86400.0
      #rotate_rev = (calc_dt + 0.8 * (year - 1990)) / 86400.0
      rotate_rev = calc_dt / 86400.0

      # 2000年1月1日力学時正午からの経過日数(日)計算
      day_progress = calc_day_progress(year, month, day)

      # 経過ユリウス年(日)計算
      # ( 2000.0(2000年1月1日力学時正午)からの経過年数 (年) )
      jy = (day_progress + t + rotate_rev) / 365.25

      # 太陽黄経計算
      th  = 0.0003 * Math.sin(K * normalize_angle(329.7  +   44.43  * jy))
      th += 0.0003 * Math.sin(K * normalize_angle(352.5  + 1079.97  * jy))
      th += 0.0004 * Math.sin(K * normalize_angle( 21.1  +  720.02  * jy))
      th += 0.0004 * Math.sin(K * normalize_angle(157.3  +  299.30  * jy))
      th += 0.0004 * Math.sin(K * normalize_angle(234.9  +  315.56  * jy))
      th += 0.0005 * Math.sin(K * normalize_angle(291.2  +   22.81  * jy))
      th += 0.0005 * Math.sin(K * normalize_angle(207.4  +    1.50  * jy))
      th += 0.0006 * Math.sin(K * normalize_angle( 29.8  +  337.18  * jy))
      th += 0.0007 * Math.sin(K * normalize_angle(206.8  +   30.35  * jy))
      th += 0.0007 * Math.sin(K * normalize_angle(153.3  +   90.38  * jy))
      th += 0.0008 * Math.sin(K * normalize_angle(132.5  +  659.29  * jy))
      th += 0.0013 * Math.sin(K * normalize_angle( 81.4  +  225.18  * jy))
      th += 0.0015 * Math.sin(K * normalize_angle(343.2  +  450.37  * jy))
      th += 0.0018 * Math.sin(K * normalize_angle(251.3  +    0.20  * jy))
      th += 0.0018 * Math.sin(K * normalize_angle(297.8  + 4452.67  * jy))
      th += 0.0020 * Math.sin(K * normalize_angle(247.1  +  329.64  * jy))
      th += 0.0048 * Math.sin(K * normalize_angle(234.95 +   19.341 * jy))
      th += 0.0200 * Math.sin(K * normalize_angle(355.05 +  719.981 * jy))
      th += (1.9146 - 0.00005 * jy) * Math.sin(K * normalize_angle(357.538 + 359.991 * jy))
      th += normalize_angle(280.4603 + 360.00769 * jy)
      return normalize_angle(th)
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".get_longitude_sun_new] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # 月の黄経 λmoon 計算
  #=========================================================================
  def calc_longitude_moon(t)
    begin
      # 摂動項の計算
      ang = normalize_angle(2322131.0  * t + 191.0 )
      th  = 0.0003 * Math.cos(K * ang)
      ang = normalize_angle(   4067.0  * t +  70.0 )
      th += 0.0003 * Math.cos(K * ang)
      ang = normalize_angle( 549197.0  * t + 220.0 )
      th += 0.0003 * Math.cos(K * ang)
      ang = normalize_angle(1808933.0  * t +  58.0 )
      th += 0.0003 * Math.cos(K * ang)
      ang = normalize_angle( 349472.0  * t + 337.0 )
      th += 0.0003 * Math.cos(K * ang)
      ang = normalize_angle( 381404.0  * t + 354.0 )
      th += 0.0003 * Math.cos(K * ang)
      ang = normalize_angle( 958465.0  * t + 340.0 )
      th += 0.0003 * Math.cos(K * ang)
      ang = normalize_angle(  12006.0  * t + 187.0 )
      th += 0.0004 * Math.cos(K * ang)
      ang = normalize_angle(  39871.0  * t + 223.0 )
      th += 0.0004 * Math.cos(K * ang)
      ang = normalize_angle( 509131.0  * t + 242.0 )
      th += 0.0005 * Math.cos(K * ang)
      ang = normalize_angle(1745069.0  * t +  24.0 )
      th += 0.0005 * Math.cos(K * ang)
      ang = normalize_angle(1908795.0  * t +  90.0 )
      th += 0.0005 * Math.cos(K * ang)
      ang = normalize_angle(2258267.0  * t + 156.0 )
      th += 0.0006 * Math.cos(K * ang)
      ang = normalize_angle( 111869.0  * t +  38.0 )
      th += 0.0006 * Math.cos(K * ang)
      ang = normalize_angle(  27864.0  * t + 127.0 )
      th += 0.0007 * Math.cos(K * ang)
      ang = normalize_angle( 485333.0  * t + 186.0 )
      th += 0.0007 * Math.cos(K * ang)
      ang = normalize_angle( 405201.0  * t +  50.0 )
      th += 0.0007 * Math.cos(K * ang)
      ang = normalize_angle( 790672.0  * t + 114.0 )
      th += 0.0007 * Math.cos(K * ang)
      ang = normalize_angle(1403732.0  * t +  98.0 )
      th += 0.0008 * Math.cos(K * ang)
      ang = normalize_angle( 858602.0  * t + 129.0 )
      th += 0.0009 * Math.cos(K * ang)
      ang = normalize_angle(1920802.0  * t + 186.0 )
      th += 0.0011 * Math.cos(K * ang)
      ang = normalize_angle(1267871.0  * t + 249.0 )
      th += 0.0012 * Math.cos(K * ang)
      ang = normalize_angle(1856938.0  * t + 152.0 )
      th += 0.0016 * Math.cos(K * ang)
      ang = normalize_angle( 401329.0  * t + 274.0 )
      th += 0.0018 * Math.cos(K * ang)
      ang = normalize_angle( 341337.0  * t +  16.0 )
      th += 0.0021 * Math.cos(K * ang)
      ang = normalize_angle(  71998.0  * t +  85.0 )
      th += 0.0021 * Math.cos(K * ang)
      ang = normalize_angle( 990397.0  * t + 357.0 )
      th += 0.0021 * Math.cos(K * ang)
      ang = normalize_angle( 818536.0  * t + 151.0 )
      th += 0.0022 * Math.cos(K * ang)
      ang = normalize_angle( 922466.0  * t + 163.0 )
      th += 0.0023 * Math.cos(K * ang)
      ang = normalize_angle(  99863.0  * t + 122.0 )
      th += 0.0024 * Math.cos(K * ang)
      ang = normalize_angle(1379739.0  * t +  17.0 )
      th += 0.0026 * Math.cos(K * ang)
      ang = normalize_angle( 918399.0  * t + 182.0 )
      th += 0.0027 * Math.cos(K * ang)
      ang = normalize_angle(   1934.0  * t + 145.0 )
      th += 0.0028 * Math.cos(K * ang)
      ang = normalize_angle( 541062.0  * t + 259.0 )
      th += 0.0037 * Math.cos(K * ang)
      ang = normalize_angle(1781068.0  * t +  21.0 )
      th += 0.0038 * Math.cos(K * ang)
      ang = normalize_angle(    133.0  * t +  29.0 )
      th += 0.0040 * Math.cos(K * ang)
      ang = normalize_angle(1844932.0  * t +  56.0 )
      th += 0.0040 * Math.cos(K * ang)
      ang = normalize_angle(1331734.0  * t + 283.0 )
      th += 0.0040 * Math.cos(K * ang)
      ang = normalize_angle( 481266.0  * t + 205.0 )
      th += 0.0050 * Math.cos(K * ang)
      ang = normalize_angle(  31932.0  * t + 107.0 )
      th += 0.0052 * Math.cos(K * ang)
      ang = normalize_angle( 926533.0  * t + 323.0 )
      th += 0.0068 * Math.cos(K * ang)
      ang = normalize_angle( 449334.0  * t + 188.0 )
      th += 0.0079 * Math.cos(K * ang)
      ang = normalize_angle( 826671.0  * t + 111.0 )
      th += 0.0085 * Math.cos(K * ang)
      ang = normalize_angle(1431597.0  * t + 315.0 )
      th += 0.0100 * Math.cos(K * ang)
      ang = normalize_angle(1303870.0  * t + 246.0 )
      th += 0.0107 * Math.cos(K * ang)
      ang = normalize_angle( 489205.0  * t + 142.0 )
      th += 0.0110 * Math.cos(K * ang)
      ang = normalize_angle(1443603.0  * t +  52.0 )
      th += 0.0125 * Math.cos(K * ang)
      ang = normalize_angle(  75870.0  * t +  41.0 )
      th += 0.0154 * Math.cos(K * ang)
      ang = normalize_angle( 513197.9  * t + 222.5 )
      th += 0.0304 * Math.cos(K * ang)
      ang = normalize_angle( 445267.1  * t +  27.9 )
      th += 0.0347 * Math.cos(K * ang)
      ang = normalize_angle( 441199.8  * t +  47.4 )
      th += 0.0409 * Math.cos(K * ang)
      ang = normalize_angle( 854535.2  * t + 148.2 )
      th += 0.0458 * Math.cos(K * ang)
      ang = normalize_angle(1367733.1  * t + 280.7 )
      th += 0.0533 * Math.cos(K * ang)
      ang = normalize_angle( 377336.3  * t +  13.2 )
      th += 0.0571 * Math.cos(K * ang)
      ang = normalize_angle(  63863.5  * t + 124.2 )
      th += 0.0588 * Math.cos(K * ang)
      ang = normalize_angle( 966404.0  * t + 276.5 )
      th += 0.1144 * Math.cos(K * ang)
      ang = normalize_angle(  35999.05 * t +  87.53)
      th += 0.1851 * Math.cos(K * ang)
      ang = normalize_angle( 954397.74 * t + 179.93)
      th += 0.2136 * Math.cos(K * ang)
      ang = normalize_angle( 890534.22 * t + 145.7 )
      th += 0.6583 * Math.cos(K * ang)
      ang = normalize_angle( 413335.35 * t +  10.74)
      th += 1.2740 * Math.cos(K * ang)
      ang = normalize_angle(477198.868 * t + 44.963)
      th += 6.2888 * Math.cos(K * ang)

      # 比例項の計算
      ang = normalize_angle(481267.8809 * t)
      ang = normalize_angle(ang + 218.3162)

      # 月黄経
      return normalize_angle(th + ang)
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".get_longitude_moon] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # 月の黄経 λmoon 計算 ( 補正 )
  #=========================================================================
  def calc_longitude_moon_new(t)
    begin
      # ユリウス通日から年月日時分秒を計算
      ymdt = jd_to_ymdt(t)
      year  = ymdt[0]
      month = ymdt[1]
      day   = ymdt[2]
      hour  = ymdt[3]
      min   = ymdt[4]
      sec   = ymdt[5]

      # 時分秒から日計算
      t  = hour * 60 * 60
      t += min * 60
      t += sec
      t /= 86400.0

      # 地球自転遅れ補正値(日)計算
      #rotate_rev = (57 + 0.8 * (year - 1990)) / 86400.0
      #rotate_rev = (calc_dt + 0.8 * (year - 1990)) / 86400.0
      rotate_rev = calc_dt / 86400.0

      # 2000年1月1日力学時正午からの経過日数(日)計算
      day_progress = calc_day_progress(year, month, day)

      # 経過ユリウス年(日)計算
      # ( 2000.0(2000年1月1日力学時正午)からの経過年数 (年) )
      jy = (day_progress + t + rotate_rev) / 365.25

      # 月黄経計算
      am  = 0.0006 * Math.sin(K * normalize_angle( 54.0 + 19.3  * jy))
      am += 0.0006 * Math.sin(K * normalize_angle( 71.0 +  0.2  * jy))
      am += 0.0020 * Math.sin(K * normalize_angle( 55.0 + 19.34 * jy))
      am += 0.0040 * Math.sin(K * normalize_angle(119.5 +  1.33 * jy))

      rm_moon  = 0.0003 * Math.sin(K * normalize_angle(280.0   + 23221.3    * jy))
      rm_moon += 0.0003 * Math.sin(K * normalize_angle(161.0   +    40.7    * jy))
      rm_moon += 0.0003 * Math.sin(K * normalize_angle(311.0   +  5492.0    * jy))
      rm_moon += 0.0003 * Math.sin(K * normalize_angle(147.0   + 18089.3    * jy))
      rm_moon += 0.0003 * Math.sin(K * normalize_angle( 66.0   +  3494.7    * jy))
      rm_moon += 0.0003 * Math.sin(K * normalize_angle( 83.0   +  3814.0    * jy))
      rm_moon += 0.0004 * Math.sin(K * normalize_angle( 20.0   +   720.0    * jy))
      rm_moon += 0.0004 * Math.sin(K * normalize_angle( 71.0   +  9584.7    * jy))
      rm_moon += 0.0004 * Math.sin(K * normalize_angle(278.0   +   120.1    * jy))
      rm_moon += 0.0004 * Math.sin(K * normalize_angle(313.0   +   398.7    * jy))
      rm_moon += 0.0005 * Math.sin(K * normalize_angle(332.0   +  5091.3    * jy))
      rm_moon += 0.0005 * Math.sin(K * normalize_angle(114.0   + 17450.7    * jy))
      rm_moon += 0.0005 * Math.sin(K * normalize_angle(181.0   + 19088.0    * jy))
      rm_moon += 0.0005 * Math.sin(K * normalize_angle(247.0   + 22582.7    * jy))
      rm_moon += 0.0006 * Math.sin(K * normalize_angle(128.0   +  1118.7    * jy))
      rm_moon += 0.0007 * Math.sin(K * normalize_angle(216.0   +   278.6    * jy))
      rm_moon += 0.0007 * Math.sin(K * normalize_angle(275.0   +  4853.3    * jy))
      rm_moon += 0.0007 * Math.sin(K * normalize_angle(140.0   +  4052.0    * jy))
      rm_moon += 0.0008 * Math.sin(K * normalize_angle(204.0   +  7906.7    * jy))
      rm_moon += 0.0008 * Math.sin(K * normalize_angle(188.0   + 14037.3    * jy))
      rm_moon += 0.0009 * Math.sin(K * normalize_angle(218.0   +  8586.0    * jy))
      rm_moon += 0.0011 * Math.sin(K * normalize_angle(276.5   + 19208.02   * jy))
      rm_moon += 0.0012 * Math.sin(K * normalize_angle(339.0   + 12678.71   * jy))
      rm_moon += 0.0016 * Math.sin(K * normalize_angle(242.2   + 18569.38   * jy))
      rm_moon += 0.0018 * Math.sin(K * normalize_angle(  4.1   +  4013.29   * jy))
      rm_moon += 0.0020 * Math.sin(K * normalize_angle( 55.0   +    19.34   * jy))
      rm_moon += 0.0021 * Math.sin(K * normalize_angle(105.6   +  3413.37   * jy))
      rm_moon += 0.0021 * Math.sin(K * normalize_angle(175.1   +   719.98   * jy))
      rm_moon += 0.0021 * Math.sin(K * normalize_angle( 87.5   +  9903.97   * jy))
      rm_moon += 0.0022 * Math.sin(K * normalize_angle(240.6   +  8185.36   * jy))
      rm_moon += 0.0024 * Math.sin(K * normalize_angle(252.8   +  9224.66   * jy))
      rm_moon += 0.0024 * Math.sin(K * normalize_angle(211.9   +   988.63   * jy))
      rm_moon += 0.0026 * Math.sin(K * normalize_angle(107.2   + 13797.39   * jy))
      rm_moon += 0.0027 * Math.sin(K * normalize_angle(272.5   +  9183.99   * jy))
      rm_moon += 0.0037 * Math.sin(K * normalize_angle(349.1   +  5410.62   * jy))
      rm_moon += 0.0039 * Math.sin(K * normalize_angle(111.3   + 17810.68   * jy))
      rm_moon += 0.0040 * Math.sin(K * normalize_angle(119.5   +     1.33   * jy))
      rm_moon += 0.0040 * Math.sin(K * normalize_angle(145.6   + 18449.32   * jy))
      rm_moon += 0.0040 * Math.sin(K * normalize_angle( 13.2   + 13317.34   * jy))
      rm_moon += 0.0048 * Math.sin(K * normalize_angle(235.0   +    19.34   * jy))
      rm_moon += 0.0050 * Math.sin(K * normalize_angle(295.4   +  4812.66   * jy))
      rm_moon += 0.0052 * Math.sin(K * normalize_angle(197.2   +   319.32   * jy))
      rm_moon += 0.0068 * Math.sin(K * normalize_angle( 53.2   +  9265.33   * jy))
      rm_moon += 0.0079 * Math.sin(K * normalize_angle(278.2   +  4493.34   * jy))
      rm_moon += 0.0085 * Math.sin(K * normalize_angle(201.5   +  8266.71   * jy))
      rm_moon += 0.0100 * Math.sin(K * normalize_angle( 44.89  + 14315.966  * jy))
      rm_moon += 0.0107 * Math.sin(K * normalize_angle(336.44  + 13038.696  * jy))
      rm_moon += 0.0110 * Math.sin(K * normalize_angle(231.59  +  4892.052  * jy))
      rm_moon += 0.0125 * Math.sin(K * normalize_angle(141.51  + 14436.029  * jy))
      rm_moon += 0.0153 * Math.sin(K * normalize_angle(130.84  +   758.698  * jy))
      rm_moon += 0.0305 * Math.sin(K * normalize_angle(312.49  +  5131.979  * jy))
      rm_moon += 0.0348 * Math.sin(K * normalize_angle(117.84  +  4452.671  * jy))
      rm_moon += 0.0410 * Math.sin(K * normalize_angle(137.43  +  4411.998  * jy))
      rm_moon += 0.0459 * Math.sin(K * normalize_angle(238.18  +  8545.352  * jy))
      rm_moon += 0.0533 * Math.sin(K * normalize_angle( 10.66  + 13677.331  * jy))
      rm_moon += 0.0572 * Math.sin(K * normalize_angle(103.21  +  3773.363  * jy))
      rm_moon += 0.0588 * Math.sin(K * normalize_angle(214.22  +   638.635  * jy))
      rm_moon += 0.1143 * Math.sin(K * normalize_angle(  6.546 +  9664.0404 * jy))
      rm_moon += 0.1856 * Math.sin(K * normalize_angle(177.525 +   359.9905 * jy))
      rm_moon += 0.2136 * Math.sin(K * normalize_angle(269.926 +  9543.9773 * jy))
      rm_moon += 0.6583 * Math.sin(K * normalize_angle(235.700 +  8905.3422 * jy))
      rm_moon += 1.2740 * Math.sin(K * normalize_angle(100.738 +  4133.3536 * jy))
      rm_moon += 6.2887 * Math.sin(K * normalize_angle(134.961 +  4771.9886 * jy + am))
      rm_moon += normalize_angle(218.3161 + 4812.67881 * jy)
      return normalize_angle(rm_moon)
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".get_longitude_moon_new] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # 角度の正規化
  # ( すなわち引数の範囲を ０≦θ＜３６０ にする )
  #=========================================================================
  def normalize_angle(angle)
    begin
      if angle < 0
        angle1  = angle * (-1)
        angle2  = (angle1 / 360.0).truncate
        angle1 -= 360 * angle2
        angle1  = 360 - angle1
      else
        angle1  = (angle / 360.0).truncate
        angle1  = angle - 360.0 * angle1
      end

      return angle1
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".normalize_angle] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # ΔT の計算
  #=========================================================================
  def calc_dt
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
      t = (@year - 1000) / 100.0
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
      when ymd < sprintf("%04d-%02d-%02d", 1972, 7, 1)
        dt = 32.184 + 10
      when ymd < sprintf("%04d-%02d-%02d", 1973, 1, 1)
        dt = 32.184 + 11
      when ymd < sprintf("%04d-%02d-%02d", 1974, 1, 1)
        dt = 32.184 + 12
      when ymd < sprintf("%04d-%02d-%02d", 1975, 1, 1)
        dt = 32.184 + 13
      when ymd < sprintf("%04d-%02d-%02d", 1976, 1, 1)
        dt = 32.184 + 14
      when ymd < sprintf("%04d-%02d-%02d", 1977, 1, 1)
        dt = 32.184 + 15
      when ymd < sprintf("%04d-%02d-%02d", 1978, 1, 1)
        dt = 32.184 + 16
      when ymd < sprintf("%04d-%02d-%02d", 1979, 1, 1)
        dt = 32.184 + 17
      when ymd < sprintf("%04d-%02d-%02d", 1980, 1, 1)
        dt = 32.184 + 18
      when ymd < sprintf("%04d-%02d-%02d", 1981, 7, 1)
        dt = 32.184 + 19
      when ymd < sprintf("%04d-%02d-%02d", 1982, 7, 1)
        dt = 32.184 + 20
      when ymd < sprintf("%04d-%02d-%02d", 1983, 7, 1)
        dt = 32.184 + 21
      when ymd < sprintf("%04d-%02d-%02d", 1985, 7, 1)
        dt = 32.184 + 22
      when ymd < sprintf("%04d-%02d-%02d", 1988, 1, 1)
        dt = 32.184 + 23
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
      when ymd < sprintf("%04d-%02d-%02d", 1988, 1, 1)
        dt = 32.184 + 23
      when ymd < sprintf("%04d-%02d-%02d", 1990, 1, 1)
        dt = 32.184 + 24
      when ymd < sprintf("%04d-%02d-%02d", 1991, 1, 1)
        dt = 32.184 + 25
      when ymd < sprintf("%04d-%02d-%02d", 1992, 7, 1)
        dt = 32.184 + 26
      when ymd < sprintf("%04d-%02d-%02d", 1993, 7, 1)
        dt = 32.184 + 27
      when ymd < sprintf("%04d-%02d-%02d", 1994, 7, 1)
        dt = 32.184 + 28
      when ymd < sprintf("%04d-%02d-%02d", 1996, 1, 1)
        dt = 32.184 + 29
      when ymd < sprintf("%04d-%02d-%02d", 1997, 7, 1)
        dt = 32.184 + 30
      when ymd < sprintf("%04d-%02d-%02d", 1999, 1, 1)
        dt = 32.184 + 31
      when ymd < sprintf("%04d-%02d-%02d", 2006, 1, 1)
        dt = 32.184 + 32
      end
    when 2005 <= @year && @year < 2050
      case
      when ymd < sprintf("%04d-%02d-%02d", 2006, 1, 1)
        dt = 32.184 + 32
      when ymd < sprintf("%04d-%02d-%02d", 2009, 1, 1)
        dt = 32.184 + 33
      when ymd < sprintf("%04d-%02d-%02d", 2012, 7, 1)
        dt = 32.184 + 34
      when ymd < sprintf("%04d-%02d-%02d", 2015, 7, 1)
        dt = 32.184 + 35
      when ymd < sprintf("%04d-%02d-%02d", 2017, 7, 1)  # <= 第27回うるう秒実施までの暫定措置
        dt = 32.184 + 36
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
    return dt
  rescue => e
    raise
  end

  #=========================================================================
  # 2000年1月1日力学時正午からの経過日数(日)
  #=========================================================================
  def calc_day_progress(year, month, day)
    begin
      # 年月日取得
      year  = year - 2000
      month = month
      day   = day

      # 1月,2月は前年の13月,14月とする
      if month < 3
        year  -= 1
        month += 12
      end

      # 経過日数(J2000.0)
      day_progress  = 365 * year + 30 * month + day - 33.5 - UTC / 24.0
      day_progress += (3 * (month + 1) / 5.0).truncate
      day_progress += (year / 4.0).truncate

      return day_progress
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".calc_day_progress] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # ユリウス日(JD)から年月日、時分秒(世界時)を計算する
  #
  #   [ 戻り値 ] ( array )
  #     ymdt[0] ... 年
  #     ymdt[1] ... 月
  #     ymdt[2] ... 日
  #     ymdt[3] ... 時
  #     ymdt[4] ... 分
  #     ymdt[5] ... 秒
  #
  #   ※ この関数で求めた年月日は、グレゴリオ暦法によって表されている。
  #=========================================================================
  def jd_to_ymdt(jd)
    begin
      ymdt = Array.new(6, 0)

      x0 = (jd + 68570).truncate
      x1 = (x0 / 36524.25).truncate
      x2 = x0 - (36524.25 * x1 + 0.75).truncate
      x3 = ((x2 + 1) / 365.2425).truncate
      x4 = x2 - (365.25 * x3).truncate + 31
      x5 = (x4.truncate / 30.59).truncate
      x6 = (x5.truncate / 11.0).truncate

      ymdt[2] = x4 - (30.59 * x5).truncate
      ymdt[1] = x5 - 12 * x6 + 2
      ymdt[0] = 100 * (x1 - 49) + x3 + x6

      # 2月30日の補正
      if ymdt[1]==2 && ymdt[2] > 28
        if ymdt[0] % 100 == 0 && ymdt[0] % 400 == 0
         ymdt[2] = 29
        elsif ymdt[0] % 4 == 0
          ymdt[2] = 29
        else
          ymdt[2] = 28
        end
      end

      tm = 86400 * (jd - jd.truncate)
      ymdt[3] = (tm / 3600.0).truncate
      ymdt[4] = ((tm - 3600 * ymdt[3]) / 60.0).truncate
      ymdt[5] = (tm - 3600 * ymdt[3] - 60 * ymdt[4]).truncate

      return ymdt
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".jd_to_ymdt] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

end

#============
# 引数クラス
#============
class Arg
  def initialize
    @dt = Time.now.strftime("%Y%m%d%H%M%S")
  end

  # 引数チェック
  def check
    begin
      return true if ARGV.size == 0

      # 正規チェック (  8桁の半角数字 )
      if  /^\d{8}$/ =~ ARGV[0]
        @dt = "#{ARGV[0]}000000"
      # 正規チェック ( 14桁の半角数字 )
      elsif /^\d{14}$/ =~ ARGV[0]
        @dt = ARGV[0]
      else
        puts "引数指定 : [ 半角数字(8桁) | 半角数字(14桁) ] "
        return false
      end

      # 日付妥当性チェック
      year  = @dt[0,4].to_i
      month = @dt[4,2].to_i
      day   = @dt[6,2].to_i
      if !Date.valid_date?(year, month, day)
        puts "引数指定 : 妥当な日付ではありません。"
        return false
      end

      # 時刻妥当性チェック
      unless /^([01][0-9]|2[0-3])[0-5][0-9][0-5][0-9]$/ =~@dt[8,6]
        puts "引数指定 : 妥当な時刻ではありません。"
        return false
      end

      return true
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".check] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  # 日時取得
  def get_dt
    return @dt
  end
end

################
####  MAIN  ####
################
begin
  # 引数チェック ( エラーなら終了 )
  obj_arg = Arg.new
  exit unless obj_arg.check

  # 計算対象日付設定
  dt = obj_arg.get_dt

  # 計算クラスインスタンス化
  obj_calc = CalcMoonage.new(dt)

  # グレゴリオ暦からユリウス通日を計算
  obj_calc.gc_to_jd

  # ユリウス通日から直前の朔を計算
  obj_calc.calc_saku

  # ユリウス通日・直前の朔から月齢を計算
  moonage = obj_calc.calc_moonage

  # ユリウス通日から直前の朔を計算 ( 補正 )
  obj_calc.calc_saku_new

  # ユリウス通日・直前の朔から月齢を計算 ( 補正 )
  moonage_new = obj_calc.calc_moonage_new

  # 計算結果出力
  puts "[#{dt[0,4]}-#{dt[4,2]}-#{dt[6,2]} #{dt[8,2]}:#{dt[10,2]}:#{dt[12,2]}]"
  puts "\t[月    齢] #{moonage}"
  puts "\t[補 正 後] #{moonage_new}"
rescue => e
  str_msg = "[EXCEPTION] " + e.to_s
  STDERR.puts str_msg
  exit 1
end

