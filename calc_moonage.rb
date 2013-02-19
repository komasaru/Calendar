# -*- coding: utf-8 -*-
#=月齢計算スクリプト
# （グレゴリオ暦から月齢を計算する）
#
# date          name            version
# 2013.02.19    mk-mode         1.00 新規作成
#
# Copyright(C) 2013 mk-mode.com All Rights Reserved.
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

#============
# 計算クラス
#============
class CalcMoonage
  def initialize(dt)
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

  # 計算結果出力
  str  = "#{dt[0,4]}-#{dt[4,2]}-#{dt[6,2]} #{dt[8,2]}:#{dt[10,2]}:#{dt[12,2]} "
  str << "の月齢 = #{moonage}"
  puts str
rescue => e
  str_msg = "[EXCEPTION] " + e.to_s
  STDERR.puts str_msg
  exit 1
end

