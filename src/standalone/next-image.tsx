/* eslint-disable @next/next/no-img-element, jsx-a11y/alt-text */
import type { ImgHTMLAttributes } from 'react';
type Props = Omit<ImgHTMLAttributes<HTMLImageElement>, 'src'> & { src: string | { src: string }; priority?: boolean; fill?: boolean };
export default function Image({ src, priority, fill, ...props }: Props) {
  void priority; void fill;
  return <img {...props} src={typeof src === 'string' ? src : src.src} />;
}
