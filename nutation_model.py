#! /usr/local/bin/python3.6
"""
章動の計算
: IAU2000A 章動理論(MHB2000, IERS2003)による
  黄経における章動(Δψ), 黄道傾斜における章動(Δε) の計算

* IAU SOFA(International Astronomical Union, Standards of Fundamental Astronomy)
  の提供する C ソースコード "nut00a.c" で実装されているアルゴリズムを使用する。
* 係数データファイルの項目について
  - 日月章動(luni-solar nutation, "dat_ls.txt")
    (左から) L L' F D Om PS PST PC EC ECT ES
  - 惑星章動(planetary nutation, "dat_pl.txt)
    (左から) L L' F D Om Lm Lv Le LM Lj Ls Lu Ln Pa PS PC ES EC
* 参考サイト
  - [SOFA Library Issue 2012-03-01 for ANSI C: Complete List](http://www.iausofa.org/2012_0301_C/sofa/)
  - [USNO Circular 179](http://aa.usno.navy.mil/publications/docs/Circular_179.php)
  - [IERS Conventions Center](http://62.161.69.131/iers/conv2003/conv2003_c5.html)

  Date          Author          Version
  2018.04.11    mk-mode.com     1.00 新規作成

Copyright(C) 2018 mk-mode.com All Rights Reserved.
---
引数 : 日時(TT（地球時）)
         書式：YYYYMMDD or YYYYMMDDHHMMSS
         無指定なら現在(システム日時)を地球時とみなす。
"""
from datetime import datetime
from datetime import date
import math
import re
import sys
import traceback

class NutationModel:
    DAT_LS = "nut_ls.txt"
    DAT_PL = "nut_pl.txt"
    PI     = 3.141592653589793238462643     # PI
    PI2    = 6.283185307179586476925287     # 2 * PI
    AS2R   = 4.848136811095359935899141e-6  # Arcseconds to radians
    TURNAS = 1296000.0                      # Arcseconds in a full circle
    U2R    = AS2R / 1e7                     # Units of 0.1 microarcsecond to radians
    R2D    = 57.29577951308232087679815     # Radians to degrees
    D2S    = 3600.0                         # Degrees to seconds

    def __init__(self):
        self.__get_arg()
        self.__get_data()

    def exec(self):
        """ 実行 """
        try:
            jd = self.__calc_jd(self.tt)
            t  = self.__calc_t(jd)
            dpsi_ls, deps_ls = self.__calc_lunisolar(t)
            dpsi_pl, deps_pl = self.__calc_planetary(t)
            self.dpsi = dpsi_ls + dpsi_pl
            self.deps = deps_ls + deps_pl
            self.dpsi_d = self.dpsi * self.R2D
            self.deps_d = self.deps * self.R2D
            self.dpsi_s = self.dpsi_d * self.D2S
            self.deps_s = self.deps_d * self.D2S
            self.__display()
        except Exception as e:
            raise

    def __get_arg(self):
        """ コマンドライン引数の取得
            * コマンドライン引数で指定した日時を self.tt に設定
            * コマンドライン引数が存在しなければ、現在時刻を self.tt に設定
        """
        try:
            if len(sys.argv) < 2:
                self.tt = datetime.now()
                return
            if re.search(r"^\d{8}$", sys.argv[1]) is not(None):
                dt = sys.argv[1] + "000000"
            elif re.search(r"^\d{14}$", sys.argv[1]) is not(None):
                dt = sys.argv[1]
            else:
                sys.exit(0)
            try:
                self.tt = datetime.strptime(dt, "%Y%m%d%H%M%S")
            except ValueError as e:
                print("Invalid date!")
                sys.exit(0)
        except Exception as e:
            raise

    def __get_data(self):
        """ テキストファイル(DAT_LS, DAT_PL)からデータ取得
            * luni-solar の最初の5列、planetary の最初の14列は整数に、
              残りの列は浮動小数点*10000にする
            * 読み込みデータは self.dat_ls, self.dat_pl に格納
        """
        self.dat_ls = []
        self.dat_pl = []
        try:
            with open(self.DAT_LS, "r") as f:
                data = f.read()
                for l in re.split('\n', data)[1:]:
                    l = re.sub(r'^\s+', "", l)
                    items = re.split(r'\s+', l)
                    if len(items) < 2:
                        break
                    items = [int(x) for x in items[:5]] \
                          + [int(re.sub(r'\.', "", x)) for x in items[5:]]
                    self.dat_ls.append(items)
            with open(self.DAT_PL, "r") as f:
                data = f.read()
                for l in re.split('\n', data)[1:]:
                    l = re.sub(r'^\s+', "", l)
                    items = re.split(r'\s+', l)
                    if len(items) < 2:
                        break
                    items = [int(x) for x in items[:14]] \
                          + [int(re.sub(r'\.', "", x)) for x in items[14:]]
                    self.dat_pl.append(items)
        except Exception as e:
            raise

    def __calc_jd(self, tt):
        """ ユリウス日の計算
            * 地球時 self.tt のユリウス日を計算し、self.jd に設定

        :param  datetime tt: 地球時
        :return float      : ユリウス日
        """
        year, month,  day    = tt.year, tt.month,  tt.day
        hour, minute, second = tt.hour, tt.minute, tt.second
        try:
            if month < 3:
                year  -= 1
                month += 12
            d = int(365.25 * year) + year // 400  - year // 100 \
              + int(30.59 * (month - 2)) + day + 1721088.5
            t  = (second / 3600 + minute / 60 + hour) / 24
            return d + t
        except Exception as e:
            raise

    def __calc_t(self, jd):
        """ ユリウス世紀数の計算
            * ユリウス日 self.jd のユリウス世紀数を計算し、 self.t に設定

        :param  float jd: ユリウス日
        :return float   : ユリウス世紀数
        """
        try:
            return (jd - 2451545) / 36525
        except Exception as e:
            raise

    def __calc_lunisolar(self, t):
        """ 日月章動(luni-solar nutation)の計算

        :param  float t: ユリウス世紀数
        :return list: [黄経における章動(Δψ), 黄道傾斜における章動(Δε)]
        """
        dp, de = 0.0, 0.0
        try:
            l  = self.__calc_l_iers2003(t)
            lp = self.__calc_lp_mhb2000(t)
            f  = self.__calc_f_iers2003(t)
            d  = self.__calc_d_mhb2000(t)
            om = self.__calc_om_iers2003(t)
            for x in reversed(self.dat_ls):
                arg = (x[0] * l + x[1] * lp + x[2] * f \
                     + x[3] * d + x[4] * om) % self.PI2
                sarg, carg = math.sin(arg), math.cos(arg)
                dp += (x[5] + x[6] * t) * sarg + x[ 7] * carg
                de += (x[8] + x[9] * t) * carg + x[10] * sarg
            return [dp * self.U2R, de * self.U2R]
        except Exception as e:
            raise

    def __calc_planetary(self, t):
        """ 惑星章動(planetary nutation)

        :param  float t: ユリウス世紀数
        :return list: [黄経における章動(Δψ), 黄道傾斜における章動(Δε)]
        """
        dp, de = 0.0, 0.0
        try:
            l   = self.__calc_l_mhb2000(t)
            f   = self.__calc_f_mhb2000(t)
            d   = self.__calc_d_mhb2000_2(t)
            om  = self.__calc_om_mhb2000(t)
            pa  = self.__calc_pa_iers2003(t)
            lme = self.__calc_lme_iers2003(t)
            lve = self.__calc_lve_iers2003(t)
            lea = self.__calc_lea_iers2003(t)
            lma = self.__calc_lma_iers2003(t)
            lju = self.__calc_lju_iers2003(t)
            lsa = self.__calc_lsa_iers2003(t)
            lur = self.__calc_lur_iers2003(t)
            lne = self.__calc_lne_mhb2000(t)
            for x in reversed(self.dat_pl):
                arg = (x[ 0] * l   + x[ 2] * f   + x[ 3] * d   + x[ 4] * om  \
                     + x[ 5] * lme + x[ 6] * lve + x[ 7] * lea + x[ 8] * lma \
                     + x[ 9] * lju + x[10] * lsa + x[11] * lur + x[12] * lne \
                     + x[13] * pa) % self.PI2
                sarg, carg = math.sin(arg), math.cos(arg)
                dp += x[14] * sarg + x[15] * carg
                de += x[16] * sarg + x[17] * carg
            return [dp * self.U2R, de * self.U2R]
        except Exception as e:
            raise

    def __calc_l_iers2003(self, t):
        """ Mean anomaly of the Moon (IERS 2003)

        :param  float t: ユリウス世紀数
        :return float  : Mean anomaly of the Moon
        """
        try:
            return ((    485868.249036    \
                  + (1717915923.2178      \
                  + (        31.8792      \
                  + (         0.051635    \
                  + (        -0.00024470) \
                  * t) * t) * t) * t) % self.TURNAS) * self.AS2R
        except Exception as e:
            raise

    def __calc_lp_mhb2000(self, t):
        """ Mean anomaly of the Sun (MHB2000)

        :param  float t: ユリウス世紀数
        :return float  : Mean anomaly of the Sun
        """
        try:
            return ((  1287104.79305     \
                  + (129596581.0481      \
                  + (       -0.5532      \
                  + (        0.000136    \
                  + (       -0.00001149) \
                  * t) * t) * t) * t) % self.TURNAS) * self.AS2R
        except Exception as e:
            raise

    def __calc_f_iers2003(self, t):
        """ Mean longitude of the Moon minus that of the ascending node
            (IERS 2003)

        :param  float t: ユリウス世紀数
        :return float  : Mean longitude of the Moon minus that of the
                         ascending node
        """
        try:
            return ((     335779.526232   \
                  + (1739527262.8478      \
                  + (       -12.7512      \
                  + (        -0.001037    \
                  + (         0.00000417) \
                  * t) * t) * t) * t) % self.TURNAS) * self.AS2R
        except Exception as e:
            raise

    def __calc_d_mhb2000(self, t):
        """ Mean elongation of the Moon from the Sun (MHB2000)

        :param  float t: ユリウス世紀数
        :return float  : Mean elongation of the Moon from the Sun
        """
        try:
            return ((   1072260.70369     \
                  + (1602961601.2090      \
                  + (        -6.3706      \
                  + (         0.006593    \
                  + (        -0.00003169) \
                  * t) * t) * t) * t) % self.TURNAS) * self.AS2R
        except Exception as e:
            raise

    def __calc_om_iers2003(self, t):
        """ Mean longitude of the ascending node of the Moon
            (IERS 2003)

        :param  float t: ユリウス世紀数
        :return float  : Mean longitude of the ascending node of the
                         Moon
        """
        try:
            return ((    450160.398036    \
                  + (  -6962890.5431      \
                  + (         7.4722      \
                  + (         0.007702    \
                  + (        -0.00005939) \
                  * t) * t) * t) * t) % self.TURNAS) * self.AS2R
        except Exception as e:
            raise

    def __calc_l_mhb2000(self, t):
        """ Mean anomaly of the Moon (MHB2000)

        :param  float t: ユリウス世紀数
        :return float  : Mean anomaly of the Moon
        """
        try:
            return (2.35555598 + 8328.6914269554 * t) % self.PI2
        except Exception as e:
            raise

    def __calc_f_mhb2000(self, t):
        """ Mean longitude of the Moon minus that of the ascending node
            (MHB2000)

        :param  float t: ユリウス世紀数
        :return float  : Mean longitude of the Moon minus that of the
                         ascending node
        """
        try:
            return (1.627905234 + 8433.466158131 * t) % self.PI2
        except Exception as e:
            raise

    def __calc_d_mhb2000_2(self, t):
        """ Mean elongation of the Moon from the Sun (MHB2000)

        :param  float t: ユリウス世紀数
        :return float  : Mean elongation of the Moon from the Sun
        """
        try:
            return (5.198466741 + 7771.3771468121 * t) % self.PI2
        except Exception as e:
            raise

    def __calc_om_mhb2000(self, t):
        """ Mean longitude of the ascending node of the Moon (MHB2000)

        :param  float t: ユリウス世紀数
        :return float  : Mean longitude of the ascending node of the
                         Moon
        """
        try:
            return (2.18243920 - 33.757045 * t) % self.PI2
        except Exception as e:
            raise

    def __calc_pa_iers2003(self, t):
        """ General accumulated precession in longitude (IERS 2003)

        :param  float t: ユリウス世紀数
        :return float  : General accumulated precession in longitude
        """
        try:
            return (0.024381750 + 0.00000538691 * t) * t
        except Exception as e:
            raise

    def __calc_lme_iers2003(self, t):
        """ Mercury longitudes (IERS 2003)

        :param  float t: ユリウス世紀数
        :return float  : Mercury longitudes
        """
        try:
            return (4.402608842 + 2608.7903141574 * t) % self.PI2
        except Exception as e:
            raise

    def __calc_lve_iers2003(self, t):
        """ Venus longitudes (IERS 2003)

        :param  float t: ユリウス世紀数
        :return float  : Venus longitudes
        """
        try:
            return (3.176146697 + 1021.3285546211 * t) % self.PI2
        except Exception as e:
            raise

    def __calc_lea_iers2003(self, t):
        """ Earth longitudes (IERS 2003)

        :param  float t: ユリウス世紀数
        :return float  : Earth longitudes
        """
        try:
            return (1.753470314 + 628.3075849991 * t) % self.PI2
        except Exception as e:
            raise

    def __calc_lma_iers2003(self, t):
        """ Mars longitudes (IERS 2003)

        :param  float t: ユリウス世紀数
        :return float  : Mars longitudes
        """
        try:
            return (6.203480913 + 334.0612426700 * t) % self.PI2
        except Exception as e:
            raise

    def __calc_lju_iers2003(self, t):
        """ Jupiter longitudes (IERS 2003)

        :param  float t: ユリウス世紀数
        :return float  : Jupiter longitudes
        """
        try:
            return (0.599546497 + 52.9690962641 * t) % self.PI2
        except Exception as e:
            raise

    def __calc_lsa_iers2003(self, t):
        """ Saturn longitudes (IERS 2003)

        :param  float t: ユリウス世紀数
        :return float  : Saturn longitudes
        """
        try:
            return (0.874016757 + 21.3299104960 * t) % self.PI2
        except Exception as e:
            raise

    def __calc_lur_iers2003(self, t):
        """ Uranus longitudes (IERS 2003)

        :param  float t: ユリウス世紀数
        :return float  : Uranus longitudes
        """
        try:
            return (5.481293872 + 7.4781598567 * t) % self.PI2
        except Exception as e:
            raise

    def __calc_lne_mhb2000(self, t):
        """ Neptune longitude (MHB2000)

        :param  float t: ユリウス世紀数
        :return float  : Neptune longitude
        """
        try:
            return (5.321159000 + 3.8127774000 * t) % self.PI2
        except Exception as e:
            raise

    def __display(self):
        """ Display """
        try:
            print((
                "  [{} TT]\n"
                "  DeltaPsi = {} rad\n"
                "           = {} °\n"
                "           = {} ″\n"
                "  DeltaEps = {} rad\n"
                "           = {} °\n"
                "           = {} ″"
            ).format(
                self.tt.strftime("%Y-%m-%d %H:%M:%S"),
                self.dpsi, self.dpsi_d, self.dpsi_s,
                self.deps, self.deps_d, self.deps_s
            ))
        except Exception as e:
            raise


if __name__ == '__main__':
    try:
        obj = NutationModel()
        obj.exec()
    except Exception as e:
        traceback.print_exc()
        sys.exit(1)

