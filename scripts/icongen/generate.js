// One-off icon generator: renders assets/brand/wishable_logo.svg into the web
// favicon + PWA icons. Run from this folder with `node generate.js`.
//
// Standard icons use the full-bleed logo. Maskable icons add a brand-colored
// safe-zone margin so the mark isn't clipped by the platform's mask.
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const root = path.resolve(__dirname, '..', '..');
const svgPath = path.join(root, 'assets', 'brand', 'wishable_logo.svg');
const svg = fs.readFileSync(svgPath);

// A maskable variant: the logo centered at ~80% on a solid brand background,
// so the platform's circular/rounded mask never clips the mark.
function maskableSvg(size) {
  const inner = Math.round(size * 0.78);
  const offset = Math.round((size - inner) / 2);
  return Buffer.from(
    `<svg width="${size}" height="${size}" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
       <rect width="${size}" height="${size}" fill="#6D5BF8"/>
       <image x="${offset}" y="${offset}" width="${inner}" height="${inner}"
              xlink:href="data:image/svg+xml;base64,${svg.toString('base64')}"/>
     </svg>`
  );
}

async function render(input, size, outFile) {
  await sharp(input, { density: 384 })
    .resize(size, size, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .png()
    .toFile(outFile);
  console.log('wrote', path.relative(root, outFile));
}

(async () => {
  const web = path.join(root, 'web');
  const icons = path.join(web, 'icons');

  // Favicon (standard, full-bleed).
  await render(svg, 64, path.join(web, 'favicon.png'));

  // PWA standard icons.
  await render(svg, 192, path.join(icons, 'Icon-192.png'));
  await render(svg, 512, path.join(icons, 'Icon-512.png'));

  // PWA maskable icons (with safe-zone background).
  await render(maskableSvg(192), 192, path.join(icons, 'Icon-maskable-192.png'));
  await render(maskableSvg(512), 512, path.join(icons, 'Icon-maskable-512.png'));

  console.log('done');
})();
