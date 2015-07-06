# eMBRLitMine
Literature mining tool that can help associate chemical compounds with microorganism that could be involved in their remediation. Will use statistics(counts) of documents in which the co-occurence exists in a cohort of relevant documents. In addition to the association between contaminant and microbe the resource also introduces an additional layer of connectivity, a concept - in this case bioremediation. To include this concept in the implementation a set of bioremediation keywords akin to the MeSH in PubMed will be created and used. Resource is based on literature contained in PubMed. Initial cohort of literature citations to come from PubMEd. NCBI's e-fetch utilities will be used. Lexicon of microorganisms (obtained from UMBBD[now EAWAG] and KEGG) to be used in perl script to fetch all relevant literature from PubMEd. This is stored in a mysql relational database. List of contaminant names for Named Entity process to be obtained from UMBBD, Encyclkopedia of environmantal contaminant and the KEGG bioremediation compounds. List of microorganisms - obtained from the UMBBD and KEGG. Publication information to be extracted: Title, Year, Journal, Volume, Pages, Abstract. 
