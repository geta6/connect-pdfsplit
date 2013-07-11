
module.exports = (options = {}) ->

  fs = require 'fs'
  path = require 'path'
  mime = require 'mime'
  mktemp = require 'mktemp'
  {exec} = require 'child_process'

  options.cache or= '/tmp'
  options.density or= 300

  return (req, res, next) ->

    pdfsplit = (src, page = 1) ->
      unless fs.existsSync src
        res.statusCode = 404
        return res.end()

      src = src.replace /'/g, "'\\''"

      exec "pdftk '#{src}' dumpdata", (err, stdout) ->
        pagemax = parseInt stdout.replace /^[\s\S]*NumberOfPages: ([0-9]+)[\s\S]*$/, '$1'
        page = 1 if page < 1
        page = pagemax if page > pagemax

        stat = fs.statSync src

        tag = "#{stat.dev}-#{stat.ino}-#{stat.mtime.getTime()}-#{page}-#{options.density}"
        if req.headers['if-none-match'] is "\"#{tag}\""
          res.statusCode = 304
          return res.end()

        dst = path.join options.cache, "#{tag}.jpg"
        img = new Buffer if fs.existsSync dst then fs.readFileSync dst else 0

        if 0 < img.length
          res.statusCode = 200
          res.setHeader 'ETag', "\"#{tag}\""
          res.setHeader 'Cache-Control', 'public'
          res.setHeader 'Content-Type', mime.lookup 'jpg'
          res.setHeader 'Content-Length', img.length
          return res.end img

        tmp = mktemp.createFileSync path.join options.cache, 'XXXXXX.pdf'
        exec "pdftk '#{src}' cat #{page} output '#{tmp}' && convert -define jpeg:density=#{options.density} -density #{options.density} '#{tmp}' '#{dst}'", (err) ->
          fs.unlinkSync tmp if fs.existsSync tmp
          img = new Buffer fs.readFileSync dst
          if err
            console.error err, src, page
            return next()
          res.statusCode = 200
          res.setHeader 'ETag', "\"#{tag}\""
          res.setHeader 'Cache-Control', 'public'
          res.setHeader 'Content-Type', mime.lookup 'jpg'
          res.setHeader 'Content-Length', img.length
          return res.end img

    res.pdfsplit = pdfsplit
    return next()
