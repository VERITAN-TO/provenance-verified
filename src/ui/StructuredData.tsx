export function StructuredData(){
 const graph={
  '@context':'https://schema.org','@graph':[
   {'@type':'Organization','@id':'https://provenanceverified.org/#organization',name:'PROVENANCE VERIFIED™',url:'https://provenanceverified.org',logo:'https://provenanceverified.org/r5/icons/app-icon-192.png'},
   {'@type':'WebSite','@id':'https://provenanceverified.org/#website',url:'https://provenanceverified.org',name:'PROVENANCE VERIFIED™',publisher:{'@id':'https://provenanceverified.org/#organization'},potentialAction:{'@type':'SearchAction',target:'https://provenanceverified.org/registry?q={search_term_string}','query-input':'required name=search_term_string'}},
   {'@type':'SoftwareApplication','@id':'https://provenanceverified.org/#platform',name:'PROVENANCE VERIFIED™',applicationCategory:'BusinessApplication',operatingSystem:'Web',description:'Independent gemstone provenance certification through claim-scoped credentials, lifecycle events, and public registry projections.',url:'https://provenanceverified.org',isAccessibleForFree:true}
  ]
 };
 return <script type="application/ld+json" dangerouslySetInnerHTML={{__html:JSON.stringify(graph).replace(/</g,'\\u003c')}}/>;
}
