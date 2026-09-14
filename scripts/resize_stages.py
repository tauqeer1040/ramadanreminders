from PIL import Image

import os, sys
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build', 'bundletool'))

for n in sys.argv[1:] or ['stage1_normal', 'stage2_expired', 'stage3_normal_again']:
    img = Image.open(n + '.png').convert('RGB')
    img.thumbnail((420, 930))
    img.save(n + '_s.jpg', quality=65)
print('3 shots resized')
