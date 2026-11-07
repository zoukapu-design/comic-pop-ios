import Foundation

@main struct TimelinePinLayoutTests {
    static func main() {
        let a=UUID(),b=UUID(),c=UUID(),d=UUID()
        let points=[
            TimelinePinPoint(id:a,seconds:0),
            TimelinePinPoint(id:b,seconds:0),
            TimelinePinPoint(id:c,seconds:5),
            TimelinePinPoint(id:d,seconds:90)
        ]
        let groups=TimelinePinLayout.clusters(points:points,duration:100,width:400)
        precondition(groups.count==2,"nearby badges should group; distant cards should remain visible")
        precondition(groups[0].points.map(\.id)==[a,b,c],"same-time pins must retain insertion order")
        precondition(groups[1].points.map(\.id)==[d],"distant card must be separate")
        precondition(groups.flatMap(\.points).count==4,"clustering must never lose any inserted card")
        precondition(groups[0].centerX==24,"first position must stay within 48pt badge margins")
        precondition(groups[1].centerX > 300,"later cards must appear later on video bar")

        let distinct=TimelinePinLayout.clusters(
            points:[TimelinePinPoint(id:a,seconds:0),
                    TimelinePinPoint(id:d,seconds:100)],
            duration:100,width:400
        )
        precondition(distinct.count==2,"start and end must have different badges")
        precondition(distinct[0].centerX==24 && distinct[1].centerX==376,
                     "start and end badges must be visible, not clipped")

        let small=TimelinePinLayout.clusters(
            points:points,duration:100,width:42
        )
        precondition(small.flatMap(\.points).count==4,
                     "narrow iPhones must retain all cards")
        precondition(small.allSatisfy{$0.centerX>=0 && $0.centerX<=42},
                     "all badges must remain inside the available width")

        let unordered=TimelinePinLayout.clusters(
            points:[TimelinePinPoint(id:d,seconds:90),
                    TimelinePinPoint(id:b,seconds:0),
                    TimelinePinPoint(id:a,seconds:0)],
            duration:100,width:400
        )
        precondition(unordered.flatMap(\.points).map(\.id)==[b,a,d],
                     "sorting must preserve equal-timestamp insertion order")

        let invalid=TimelinePinLayout.clusters(points:points,duration:0,width:400)
        precondition(invalid.isEmpty,"no markers before video duration is known")
        precondition(TimelinePinLayout.clusters(points:points,duration:100,width:0).isEmpty)
        precondition(TimelinePinLayout.clusters(points:[],duration:100,width:400).isEmpty)
        let outOfBounds=TimelinePinLayout.clusters(
            points:[TimelinePinPoint(id:a,seconds:-100),
                    TimelinePinPoint(id:d,seconds:1000)],
            duration:100,width:400
        )
        precondition(outOfBounds.count==2,"out-of-range timestamp positions must be clamped")
        precondition(outOfBounds[0].centerX==24 && outOfBounds[1].centerX==376)
        print("PASS: pin timeline marker positions, equal timestamps, clustering, narrow widths and lossless card mapping")
    }
}
