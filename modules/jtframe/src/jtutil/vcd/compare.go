package vcd

import (
    "fmt"
    "strings"
    "os"
)

type cmpData struct{
    file   *LnFile
    data    vcdData
    signal *VCDSignal
}

func (this cmpData) next() bool {
    return this.file.NextVCD(this.data)
}

func Compare( fnames []string, sname string ) {
    d := cmpReadin( fnames, sname )
    defer d[0].file.Close()
    defer d[1].file.Close()
    mismatch := false
    var last [2]uint64
    for k:=0; k<2; k++ {
        d[k].next()
        last[k] = d[k].signal.Value
    }
    report := func() {
        mismatch = d[0].signal.Value != d[1].signal.Value
        if mismatch {
            fmt.Printf("Mismatch at times %d (%s) and %d (%s)\n\t%X != %X\n",
                d[0].file.time, d[0].file.fname,
                d[1].file.time, d[1].file.fname,
                d[0].signal.Value, d[1].signal.Value )
        }
    }
    update := func() {
        last[0] = d[0].signal.Value
        last[1] = d[1].signal.Value
    }
    top:
    for {
        for k:=0; k<2; k++ {
            if !d[k].next() {
                fmt.Println("EOF:",d[k].file.fname)
                break top
            }
        }
        if d[0].signal.Value == d[1].signal.Value {
            update()
            continue
        }
        if d[0].signal.Value != last[0] && d[1].signal.Value!=last[1] {
            report()
            break
        }
        for k:=0; k<2;k++ {
            other := 1-k
            if d[k].signal.Value != last[k] {
                for d[other].signal.Value==last[other]{ d[other].next() }
                if report(); mismatch { break top }
            }
        }
        update()
    }
    if !mismatch {
        fmt.Println("No differences found")
    }
}

// Open the VCD files, get the VCD signal information and
// find the required signal to compare. Caller must close the files
func cmpReadin( fnames []string, sname string ) [2]cmpData {
    var c [2]cmpData

    for k:=0; k<2; k++ {
        c[k].file = &LnFile{}
        if !strings.HasSuffix(fnames[k],".vcd") {
            fnames[k] += ".vcd"
        }
        c[k].file.Open(fnames[k])
        c[k].data = GetSignals(c[k].file)
        all := c[k].data.GetAll(sname)
        if all == nil {
            fmt.Println("Cannot find any signal named",sname,"in",fnames[k])
            os.Exit(1)
        }
        if len(all)>1 {
            fmt.Println("Found multiple signals named similarly")
            for _,k := range all {
                fmt.Println("\t",k.Name)
            }
            fmt.Println("Please specify the name better")
            os.Exit(1)
        }
        fmt.Println("Found",all[0].FullName(), "in", fnames[k])
        c[k].signal=all[0]
    }
    return c
}