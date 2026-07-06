# A handful of pixels: doing big science with small data

In this free book I will focus on a set of examples which are rather limited in spatial scope, using just a handfull of pixels. In contrast to what the cloud computing revolution promised, many ideas start out from site or localized studies. The focus of this book on using just a handfull of pixels is therefore deliberate. This allows data to be as large as required, but as small as possible.

Not only does this allow you to experiment with geo-spatial data on limited compute infrastructure, it also shows you that true science can be done with relatively modest means. You will learn to do big science with small data.

This book is proudly GPT free, mistakes are my own.

## Contributing

The original course can be found [here](https://github.com/bluegreen-labs/handful_of_pixels), of which this is a subset.

![](https://i.creativecommons.org/l/by-nc-nd/4.0/88x31.png)


## Rendering and publishing

Quarto books can be rendered and published either manually or then via GitHub actions.
This book here requires manual rendering and publishing.
For publishing, ensure the name of the git remote is "origin", then:
```
cd GitHub/geco-bern/handfull_of_pixels
quarto render book --cache-refresh --execute-dir="book"
quarto publish book
```
