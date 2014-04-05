package require snit


snit::type font::bdf {

    variable props -array {}
    variable chars -array {}


    constructor {filename} {
        $self Read $filename
    }


    method properties {} {
        return [lsort [array names props]]
    }


    method property {name} {
        return $props($name)
    }


    method chars {} {
        return [lsort -dict [array names chars]]
    }


    method char {code} {
        return [expr {[info exists chars($code)] ? $chars($code) : ""}]
    }


    method Read {filename} {
        set f [open $filename r]

        while 1 {
            set charsRead [chan gets $f line]
            if {$charsRead == -1} {
                break
            } else {
                switch -regexp -matchvar M -- $line {
                    {^STARTFONT\s+(\d+\.\d+)} {
                        set props(version) [lindex $M 1]
                    }
                    {^ENDFONT} {
                        break
                    }

                    {^FONT\s+(.*)$} {
                        set props(font) [lindex $M 1]
                    }
                    {^SIZE\s+(\d+\s+\d+\s+\d+)\s*$} {
                        set props(size) [lindex $M 1]
                    }
                    {^FONTBOUNDINGBOX\s+(\d+\s+\d+)\s+(-?\d+\s+-?\d+)\s*$} {
                        set props(fontboundingbox) [concat [lindex $M 1] [lindex $M 2]]
                    }

                    {^STARTPROPERTIES\s(\d+)\s*$} {
                        $self ReadProperties $f [lindex $M 1]
                    }

                    {^CHARS\s+(\d+)\s*$} {
                        set props(chars) [lindex $M 1]
                    }

                    {^STARTCHAR} {
                        $self ReadChar $f [lindex $M 1]
                    }

                    {^\s*$} {}

                    default {
                        return -code error "invalid line \"$line\""
                    }
                }
            }
        }

        close $f
    }


    method ReadProperties {channel quantity} {
        while 1 {
            set charsRead [chan gets $channel line]
            if {$charsRead == -1} {
                return -code error "ENDPROPERTIES not found"
            } else {
                switch -regexp -matchvar M -- $line {
                    {^ENDPROPERTIES\s*$} {
                        break
                    }

                    {^(\w+)\s+(\d+)\s*$} -
                    {^(\w+)\s+"([^\"]*)"\s*$} {
                        if {$quantity > 0} {
                            set props([string tolower [lindex $M 1]]) [lindex $M 2]
                            incr quantity -1
                        } else {
                            return -code error "too many properties"
                        }
                    }

                    default {
                        return -code error "invalid property, should be 'word integer' or 'word \"string\"' in \"$line\""
                    }
                }
            }
        }
    }


    method ReadChar {channel name} {
        set char [dict create]

        set readBitmap 0
        set hexDataRemains 0

        while 1 {
            set charsRead [chan gets $channel line]
            if {$charsRead == -1} {
                return -code error "ENDCHAR not found"
            } elseif {$readBitmap == 1} {
                switch -regexp -matchvar M -- $line {
                    {^([0-9A-Fa-f]+)\s*$} {
                        dict lappend char bitmap [lindex $M 1]
                        incr hexDataRemains -1
                        if {$hexDataRemains > 0} {
                        } else {
                            set readBitmap 0
                        }
                    }

                    {^\s*$} {
                        # skip empty lines
                    }

                    default {
                        return -code error "invalid hex data in string \"$line\""
                    }
                }
            } else {
                switch -regexp -matchvar M -- $line {
                    {^ENDCHAR\s*$} {
