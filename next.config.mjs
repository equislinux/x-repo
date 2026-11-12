/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
  basePath: '/x-repo',
  images: {
    unoptimized: true,
  },
};

export default nextConfig;