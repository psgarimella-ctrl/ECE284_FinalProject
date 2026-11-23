# Generate random test data for the 8x8 systolic array (Part 1 flow)
import numpy as np
np.random.seed(0)
IC, OC, K, H = 8, 8, 3, 6          # 6x6 padded input, 4x4 output
x = np.random.randint(0, 16, size=(IC, H, H))          # unsigned 4-bit activations
w = np.random.randint(-8, 8, size=(OC, IC, K, K))      # signed 4-bit weights

def b(v, n): return format(int(v) & ((1 << n) - 1), f'0{n}b')

# activation_tile0.txt: 36 lines, ic7 ... ic0 (ic0 in the lowest bits)
with open('activation_tile0.txt', 'w') as f:
    f.write('#time0row7[msb-lsb]\n#time1row7[msb-lsb]\n#................\n')
    for nij in range(H*H):
        f.write(''.join(b(x[ic, nij//H, nij%H], 4) for ic in reversed(range(IC))) + '\n')

# weight files: line t = output channel t; nibble r = input channel r
for kij in range(K*K):
    ki, kj = divmod(kij, K)
    with open(f'weight_itile0_otile0_kij{kij}.txt', 'w') as f:
        f.write('#col0row7[msb-lsb]\n#col1row7[msb-lsb]\n#................\n')
        for oc in range(OC):
            f.write(''.join(b(w[oc, ic, ki, kj], 4) for ic in reversed(range(IC))) + '\n')

# acc_address.txt: for each output pixel, the 9 pmem addresses (kij*36 + nij')
with open('acc_address.txt', 'w') as f:
    f.write('#onij0kij0\n#onij0kij1\n#..........\n')
    for oi in range(4):
        for oj in range(4):
            for kij in range(K*K):
                ki, kj = divmod(kij, K)
                f.write(b(kij*H*H + (oi+ki)*H + (oj+kj), 11) + '\n')

# out.txt: expected sfp_out per output pixel (conv + ReLU), oc7 ... oc0
with open('out.txt', 'w') as f:
    f.write('#onij0[oc7...oc0]\n#onij1[oc7...oc0]\n#................\n')
    for oi in range(4):
        for oj in range(4):
            vals = []
            for oc in range(OC):
                s = sum(int(w[oc, ic, ki, kj]) * int(x[ic, oi+ki, oj+kj])
                        for ic in range(IC) for ki in range(K) for kj in range(K))
                vals.append(max(s, 0))
            f.write(''.join(b(vals[oc], 16) for oc in reversed(range(OC))) + '\n')
print('done')
