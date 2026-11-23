# gen_part2.py  --  Part 2, Step 1: stimulus + golden Y0 for ONE tile (no numpy)
import random

IC, OC, K = 8, 8, 3          # 8 input ch, 8 output ch, 3x3 kernel
H, W_ = 16, 16               # frame size (assumed 8 x 16 x 16, channel-major)
T_IN, T_OUT = 6, 4           # tile: 6x6 padded input patch -> 4x4 outputs
ACC_BW = 24                  # SFU output width per column
TILE_R, TILE_C = 0, 0        # which tile (0..3, 0..3); start with the top-left one

# ---------- 1. read X0 ----------
vals = [int(v) for v in open('X0.txt').read().split()]
assert len(vals) == IC * H * W_

# ---------- 2. reshape to x[ic][r][c]  (channel-major) ----------
x = [[[vals[ic*H*W_ + r*W_ + c] for c in range(W_)] for r in range(H)] for ic in range(IC)]

# ---------- 3. zero-pad by 1 on every side -> 8 x 18 x 18 ----------
xp = [[[0]*(W_+2) for _ in range(H+2)] for _ in range(IC)]
for ic in range(IC):
    for r in range(H):
        for c in range(W_):
            xp[ic][r+1][c+1] = x[ic][r][c]

# ---------- 4. weights (replace with your trained layer later) ----------
random.seed(0)
w = [[[[random.randint(-8, 7) for kj in range(K)] for ki in range(K)]
      for ic in range(IC)] for oc in range(OC)]

# ---------- 5. cut one 6x6 tile ----------
r0, c0 = 4*TILE_R, 4*TILE_C
tile = [[[xp[ic][r0+r][c0+c] for c in range(T_IN)] for r in range(T_IN)] for ic in range(IC)]

# ---------- 6. split into nibbles ----------
high = [[[v >> 4 for v in row] for row in ch] for ch in tile]    # signed   -8..7
low  = [[[v & 15 for v in row] for row in ch] for ch in tile]    # unsigned  0..15

# ---------- helpers ----------
def b(v, n):                          # two's complement, n bits
    return format(v & ((1 << n) - 1), '0%db' % n)

def conv(a):                          # raw 3x3 conv on a 6x6 tile -> y[oc][oi][oj] (4x4), no ReLU
    return [[[sum(w[oc][ic][ki][kj] * a[ic][oi+ki][oj+kj]
                  for ic in range(IC) for ki in range(K) for kj in range(K))
              for oj in range(T_OUT)] for oi in range(T_OUT)] for oc in range(OC)]

def write_act(name, a):               # 36 lines x 32 bits, ic7 ... ic0
    with open(name, 'w') as f:
        f.write('#time0row7[msb-lsb]\n#time1row7[msb-lsb]\n#................\n')
        for nij in range(T_IN*T_IN):
            f.write(''.join(b(a[ic][nij//T_IN][nij%T_IN], 4) for ic in reversed(range(IC))) + '\n')

# ---------- 7. write files ----------
write_act('act_x0_high.txt', high)
write_act('act_x0_low.txt',  low)

for kij in range(K*K):
    ki, kj = divmod(kij, K)
    with open('weight_itile0_otile0_kij%d.txt' % kij, 'w') as f:
        f.write('#col0row7[msb-lsb]\n#col1row7[msb-lsb]\n#................\n')
        for oc in range(OC):
            f.write(''.join(b(w[oc][ic][ki][kj], 4) for ic in reversed(range(IC))) + '\n')

with open('acc_address.txt', 'w') as f:
    f.write('#onij0kij0\n#onij0kij1\n#..........\n')
    for oi in range(T_OUT):
        for oj in range(T_OUT):
            for kij in range(K*K):
                ki, kj = divmod(kij, K)
                f.write(b(kij*T_IN*T_IN + (oi+ki)*T_IN + (oj+kj), 11) + '\n')

y_high, y_low, y_ref = conv(high), conv(low), conv(tile)
Y0 = [[[16*y_high[o][i][j] + y_low[o][i][j] for j in range(T_OUT)] for i in range(T_OUT)] for o in range(OC)]

with open('out_y0.txt', 'w') as f:
    f.write('#onij0[oc7...oc0]\n#onij1[oc7...oc0]\n#................\n')
    for oi in range(T_OUT):
        for oj in range(T_OUT):
            f.write(''.join(b(Y0[oc][oi][oj], ACC_BW) for oc in reversed(range(OC))) + '\n')

# ---------- 8. self-check ----------
assert Y0 == y_ref, 'nibble split is NOT exact'
flat = [v for o in Y0 for i in o for v in i]
print('Self-check passed: 16*conv(high) + conv(low) == conv(X0) for all %d outputs' % len(flat))
print('Y0 range: %d .. %d' % (min(flat), max(flat)))
print('high nibble range: %d .. %d' % (min(v for ch in high for r in ch for v in r), max(v for ch in high for r in ch for v in r)))
print('low  nibble range: %d .. %d' % (min(v for ch in low for r in ch for v in r), max(v for ch in low for r in ch for v in r)))
