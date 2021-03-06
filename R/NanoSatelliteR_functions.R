#' Loads summary files generated by Signal2chunk.R 
#'
#' load_summary() returns a data frame which combines summary files generated 
#' by Signal2chunk.R
#' 
#' This function requires a path to the results produced by Signal2chunk.R 
#' load_summary() will recursively search the directory and combine the 
#' .table files in a single dataframe. 
#'
#' @param dir Path denoted as a character vector of length 1. 
#' @examples 
#' df <- load_summary("/storage/NanoSatellite_chunks/") 
#' @export
load_summary=function(dir){
  summary_files=list.files(dir,".table",recursive = T,full.names = T)
  summaries=lapply(summary_files,read.table,sep="\t",header=T,stringsAsFactors=F)
  summaries_df=do.call("rbind",summaries)
  a=gsub("_.*","",sapply(strsplit(summary_files,"/"),function(x) x[length(x) -1]))
  summaries_df$sample=rep(a,sapply(summaries,nrow))
  summaries_df
}

#' Quality control of NanoSatellite delineation and segmentation
#'
#' summary_qc() returns (box)plots and suggested cutoff values to filter 
#' tandem repeat segmentations based on normalized distance.
#'
#' This function requires a data frame as generated by load_summary().
#' summary_qc() will analyze the normalized "flank" and  
#' "center" dynamic time warping distance,
#' respectively corresponding to delineation of tandem repeat squiggles
#' from flanking squiggles, and the segmentation of the tandem repeat
#' squiggle. A scatter plot of both distances is shown as well as boxplots
#' for the individual metrics. In addition, cutoff values corresponding 
#' to 1.5 times the interquartile range from 
#' the 75th percentile are returned.
#' @param df data.frame generated by load_summary()
#' @examples
#' df <- load_summary("/storage/NanoSatellite_chunks/")
#' qc <- summary_qc(df)
#' @export
summary_qc=function(df){
  flank_cutoff=boxplot(df$avg_flank_normdist,plot=F)$stats[5,]
  center_cutoff=boxplot(df$avg_center_normdist,plot=F)$stats[5,]

  opar=par(no.readonly = TRUE)
  par(mfrow=c(2,2))

  plot(df$avg_flank_normdist ~ df$avg_center_normdist,xlab="Mean center normalized distance",ylab="Mean flank normalized distance")
  abline(v=center_cutoff,col="red")
  abline(h=flank_cutoff,col="red")

  boxplot(df$avg_flank_normdist)
  abline(h=flank_cutoff,col="red")

  boxplot(df$avg_center_normdist,horizontal = T)
  abline(v=center_cutoff,col="red")
  par(opar)

  list(flank_cutoff=flank_cutoff,center_cutoff=center_cutoff)
}

#' Wrapper function to filter sequencing reads based on distance cutoffs
#'
#' Returns a data.frame containing sequencing reads with a "flank" and/or 
#' "center" normalized dynamic time warping distance smaller or equal to
#' a user specified cutoff value.
#' @param df A data.frame, generated by load_summary()
#' @param flank_cutoff A numeric value [0-1] corresponding to the maximum
#' flank normalized dynamic time warping distance
#' @param center_cutoff A numeric value [0-1] corresponding to the maximum
#' center normalized dynamic time warping distance
#' @examples
#' df <- load_summary("/storage/NanoSatellite_chunks/")
#' qc <- summary_qc(df)
#' df2 <- qual_reads(df,qc$center_cutoff)
#' @export
qual_reads=function(df,center_cutoff=1,flank_cutoff=1){
  df[df$avg_center_normdist <= center_cutoff & df$avg_flank_normdist <= flank_cutoff,]
}

#' Wrapper function to plot tandem repeat lengths for multiple samples.
#'
#' plot_lengths() returns a ggplot2 based plot with each sample in a
#' panel, the number of tandem repeat units on the y-axis, and colored
#' dots corresponding to positive (red) and negative (blue) DNA strands
#'
#' @param df data.frame generated by load_summary(), or qual_reads()
#' @param binwidth A numeric value passed on to geom_dotplot()
#' @examples
#' df <- load_summary("/storage/NanoSatellite_chunks/")
#' qc <- summary_qc(df)
#' df2 <- qual_reads(df,qc$center_cutoff)
#' plot_lengths(df2)
#' @export
plot_lengths=function(df,binwidth=5){
  library(ggplot2)
  df$strand_factor=factor(df$strand,levels=c("positive","negative"))

  ggplot()+
    geom_dotplot(data=df,aes(x=1,y=repeat_units,fill=strand_factor,colour=strand_factor),binaxis="y",stackdir="center",binwidth=binwidth,binpositions = "all",stackgroups = T)+
    theme_bw()+
    facet_grid(. ~ sample)+
    theme(axis.title=element_blank(),axis.text.x=element_blank(),axis.ticks.x=element_blank(),panel.grid.major.x = element_blank(),panel.grid.minor.x = element_blank(),strip.background =element_rect(fill="white"),strip.text=element_text(face="bold",size = 8))+
    guides(colour=FALSE,fill=FALSE)
}

#' Loads raw squiggle data generated by Signal2chunk.R
#' 
#' load_squiggles() returns a list of raw Oxford Nanopore current squiggle
#' data as generated by Signal2chunk.R
#'
#' This function requires a path to the results produced by Signal2chunk.R 
#' load_squiggles() will recursively search the directory and read all
#' .chunk files. Results are shown in a list separated by their respective
#' positive or negative DNA strand origin. Optionally a data.frame generated
#' by qual_reads() can be provided to load only reads passing QC.
#' @param  dir Path denoted as a character vector of length 1.
#' @param df An optional data.frame generated by qual_reads() to selectively
#' load squiggles.
#' @examples
#' df <- load_summary("/storage/NanoSatellite_chunks/")
#' qc <- summary_qc(df)
#' df2 <- qual_reads(df,qc$center_cutoff)
#' squiggles <- load_squiggles("/storage/NanoSatellite_chunks/",df2)
#' @export
load_squiggles=function(dir,df=NULL){
  chunk_files=list(positive=list.files(dir,"positive",full.names = T,recursive=T),
                   negative=list.files(dir,"negative",full.names = T,recursive=T))

  if(is.null(df)==F){
    a=lapply(chunk_files,gsub,pattern=".*/|_.*",replacement="")
    b=lapply(a,function(x) x %in% df$name)
    chunk_files=mapply(function(x,y) x[y],chunk_files,b)
  }

  chunk_names=sapply(chunk_files,gsub,pattern=".*/",replacement="")

  chunk_list=lapply(chunk_files, function(y){
    lapply(y, function(x){
      xxx = read.table(x,sep="\t",header=T,stringsAsFactors = F)
      xxx$signalz=as.numeric(scale(xxx$signal))
      xxx
    })
  })

  chunk_list=mapply(function(x,y){
    xxx=x
    names(xxx)=y
    xxx},chunk_list,chunk_names)

  lapply(chunk_list, function(y) lapply(y,function(x) x$signalz))
  }

#' Custom heatmap function
#'
#' This function is slightly adapted from the base heatmap() function
#' to allow control over the line width of the dendrograms. It is
#' recommended to run ns_heatmap() which incorporates heatmap_custom().
#' @export
heatmap_custom=function (x, Rowv = NULL, Colv = if (symm) "Rowv" else NULL,
                         distfun = dist, hclustfun = hclust, reorderfun = function(d,
                                                                                   w) reorder(d, w), add.expr, symm = FALSE, revC = identical(Colv,
                                                                                                                                              "Rowv"), scale = c("row", "column", "none"), na.rm = TRUE,
                         margins = c(5, 5), ColSideColors, RowSideColors, cexRow = 0.2 +
                           1/log10(nr), cexCol = 0.2 + 1/log10(nc), labRow = NULL,
                         labCol = NULL, main = NULL, xlab = NULL, ylab = NULL, keep.dendro = FALSE,
                         verbose = getOption("verbose"),lwd = 10, ...)
{
  scale <- if (symm && missing(scale))
    "none"
  else match.arg(scale)
  if (length(di <- dim(x)) != 2 || !is.numeric(x))
    stop("'x' must be a numeric matrix")
  nr <- di[1L]
  nc <- di[2L]
  if (nr <= 1 || nc <= 1)
    stop("'x' must have at least 2 rows and 2 columns")
  if (!is.numeric(margins) || length(margins) != 2L)
    stop("'margins' must be a numeric vector of length 2")
  doRdend <- !identical(Rowv, NA)
  doCdend <- !identical(Colv, NA)
  if (!doRdend && identical(Colv, "Rowv"))
    doCdend <- FALSE
  if (is.null(Rowv))
    Rowv <- rowMeans(x, na.rm = na.rm)
  if (is.null(Colv))
    Colv <- colMeans(x, na.rm = na.rm)
  if (doRdend) {
    if (inherits(Rowv, "dendrogram"))
      ddr <- Rowv
    else {
      hcr <- hclustfun(distfun(x))
      ddr <- as.dendrogram(hcr)
      if (!is.logical(Rowv) || Rowv)
        ddr <- reorderfun(ddr, Rowv)
    }
    if (nr != length(rowInd <- order.dendrogram(ddr)))
      stop("row dendrogram ordering gave index of wrong length")
  }
  else rowInd <- 1L:nr
  if (doCdend) {
    if (inherits(Colv, "dendrogram"))
      ddc <- Colv
    else if (identical(Colv, "Rowv")) {
      if (nr != nc)
        stop("Colv = \"Rowv\" but nrow(x) != ncol(x)")
      ddc <- ddr
    }
    else {
      hcc <- hclustfun(distfun(if (symm)
        x
        else t(x)))
      ddc <- as.dendrogram(hcc)
      if (!is.logical(Colv) || Colv)
        ddc <- reorderfun(ddc, Colv)
    }
    if (nc != length(colInd <- order.dendrogram(ddc)))
      stop("column dendrogram ordering gave index of wrong length")
  }
  else colInd <- 1L:nc
  x <- x[rowInd, colInd]
  labRow <- if (is.null(labRow))
    if (is.null(rownames(x)))
      (1L:nr)[rowInd]
  else rownames(x)
  else labRow[rowInd]
  labCol <- if (is.null(labCol))
    if (is.null(colnames(x)))
      (1L:nc)[colInd]
  else colnames(x)
  else labCol[colInd]
  if (scale == "row") {
    x <- sweep(x, 1L, rowMeans(x, na.rm = na.rm), check.margin = FALSE)
    sx <- apply(x, 1L, sd, na.rm = na.rm)
    x <- sweep(x, 1L, sx, "/", check.margin = FALSE)
  }
  else if (scale == "column") {
    x <- sweep(x, 2L, colMeans(x, na.rm = na.rm), check.margin = FALSE)
    sx <- apply(x, 2L, sd, na.rm = na.rm)
    x <- sweep(x, 2L, sx, "/", check.margin = FALSE)
  }
  lmat <- rbind(c(NA, 3), 2:1)
  lwid <- c(if (doRdend) 1 else 0.05, 4)
  lhei <- c((if (doCdend) 1 else 0.05) + if (!is.null(main)) 0.2 else 0,
            4)
  if (!missing(ColSideColors)) {
    if (!is.character(ColSideColors) || length(ColSideColors) !=
        nc)
      stop("'ColSideColors' must be a character vector of length ncol(x)")
    lmat <- rbind(lmat[1, ] + 1, c(NA, 1), lmat[2, ] + 1)
    lhei <- c(lhei[1L], 0.2, lhei[2L])
  }
  if (!missing(RowSideColors)) {
    if (!is.character(RowSideColors) || length(RowSideColors) !=
        nr)
      stop("'RowSideColors' must be a character vector of length nrow(x)")
    lmat <- cbind(lmat[, 1] + 1, c(rep(NA, nrow(lmat) - 1),
                                   1), lmat[, 2] + 1)
    lwid <- c(lwid[1L], 0.2, lwid[2L])
  }
  lmat[is.na(lmat)] <- 0
  if (verbose) {
    cat("layout: widths = ", lwid, ", heights = ", lhei,
        "; lmat=\n")
    print(lmat)
  }
  dev.hold()
  on.exit(dev.flush())
  op <- par(no.readonly = TRUE)
  on.exit(par(op), add = TRUE)
  layout(lmat, widths = lwid, heights = lhei, respect = TRUE)
  if (!missing(RowSideColors)) {
    par(mar = c(margins[1L], 0, 0, 0.5))
    image(rbind(if (revC)
      nr:1L
      else 1L:nr), col = RowSideColors[rowInd], axes = FALSE)
  }
  if (!missing(ColSideColors)) {
    par(mar = c(0.5, 0, 0, margins[2L]))
    image(cbind(1L:nc), col = ColSideColors[colInd], axes = FALSE)
  }
  par(mar = c(margins[1L], 0, 0, margins[2L]))
  if (!symm || scale != "none")
    x <- t(x)
  if (revC) {
    iy <- nr:1
    if (doRdend)
      ddr <- rev(ddr)
    x <- x[, iy]
  }
  else iy <- 1L:nr
  image(1L:nc, 1L:nr, x, xlim = 0.5 + c(0, nc), ylim = 0.5 +
          c(0, nr), axes = FALSE, xlab = "", ylab = "", ...)
  axis(1, 1L:nc, labels = labCol, las = 2, line = -0.5, tick = 0,
       cex.axis = cexCol)
  if (!is.null(xlab))
    mtext(xlab, side = 1, line = margins[1L] - 1.25)
  axis(4, iy, labels = labRow, las = 2, line = -0.5, tick = 0,
       cex.axis = cexRow)
  if (!is.null(ylab))
    mtext(ylab, side = 4, line = margins[2L] - 1.25)
  if (!missing(add.expr))
    eval.parent(substitute(add.expr))
  par(mar = c(margins[1L], 0, 0, 0))
  if (doRdend)
    plot(ddr, horiz = TRUE, axes = FALSE, yaxs = "i", leaflab = "none",edgePar=list(lwd=lwd))
  else frame()
  par(mar = c(0, 0, if (!is.null(main)) 1 else 0, margins[2L]))
  if (doCdend)
    plot(ddc, axes = FALSE, xaxs = "i", leaflab = "none",edgePar=list(lwd=lwd))
  else if (!is.null(main))
    frame()
  if (!is.null(main)) {
    par(xpd = NA)
    title(main, cex.main = 1.5 * op[["cex.main"]])
  }
  invisible(list(rowInd = rowInd, colInd = colInd, Rowv = if (keep.dendro &&
                                                              doRdend) ddr, Colv = if (keep.dendro && doCdend) ddc))
}

#' Create a heatmap from clustered tandem repeat squiggles.
#'
#' This function writes a png figure containing a heatmap based on a distance
#' matrix of clustered tandem repeat squiggle units.
#'
#' To visually inspect clustering, a heatmap can be constructed. Due to the 
#' potential large distance matrices generated by dtwclust::tsclust(),
#' creating heatmaps can be troublesome. 
#' ns_heatmap() should be able to deal with large distance matrices.
#' Distances in the resulting heatmap are shown with a color scale: 
#' Black = low distance, white = medium distance, red = high distance.
#' In addition, this function provides a few parameters to change thickness
#' of dendrograms and remove extreme distances.
#'
#' @param distmat A distance matrix, generated by dtwclust::tsclust()
#' @param file A character of length 1 containing path and name of the file.
#' @param lwd Dendrogram line width 
#' @param max_dist Remove distances higher than this numeric value (to obtain a
#' graphically relevant color scale)
#' @param rm0 A logical indicating wether distance equal to zero should be 
#' removed (to obtain a graphically relevant color scale)
#' @examples
#' df <- load_summary("/storage/NanoSatellite_chunks/")
#' qc <- summary_qc(df)
#' df2 <- qual_reads(df,qc$center_cutoff)
#' squiggles <- load_squiggles("/storage/NanoSatellite_chunks/",df2)
#'
#' library(doParallel)
#' library(dtwclust)
#' k_clusters=2
#' registerDoParallel(cores=8)
#'
#' positive_clustering=tsclust(squiggles$positive,type="h",k=k_clusters,trace=TRUE,distance = "dtw_basic", control=hierarchical_control(method="ward.D",symmetric = T))
#' ns_heatmap(positive_clustering@distmat,"~/test.png",max_dist=200,rm0=T)
#' @export
ns_heatmap=function(distmat,file,lwd=10,max_dist=NA,rm0=F){
  ns_hclust=hclust(stats::as.dist(distmat,diag = T),method="ward.D")
  ns_dendro=as.dendrogram(ns_hclust)
  colfunc <- colorRampPalette(c("black", "white", "red"))
  if(is.na(max_dist)==F){
    distmat[distmat > max_dist]=NA
  }
  if(rm0==T){
    distmat[distmat==0]=NA
  }
  png(file,width = 10000,height=10000)
  heatmap_custom(distmat,labRow = NA,labCol=NA,symm=T,Rowv=ns_dendro,col=colfunc(15))
  dev.off()
}

#' Extract tandem repeat unit squiggle centroids.
#'
#' extract_centroids() obtains the squiggle current levels which best represent
#' their respective clusters.
#' 
#' dtwclust::tsclust() can be used to cluster tandem repeat unit squiggles
#' and centroids are calculated for each cluster. This centroid
#' aims to provide the the most representative squiggle current level for 
#' each cluster. extract_centroids extracts the centroid information from a
#' tsclust object and returns a data.frame with the results
#' 
#' @param tsclust_obj A tsclust object generated by dtwclust::tsclust()
#' @examples
#' df <- load_summary("/storage/NanoSatellite_chunks/")
#' qc <- summary_qc(df)
#' df2 <- qual_reads(df,qc$center_cutoff)
#' squiggles <- load_squiggles("/storage/NanoSatellite_chunks/",df2)
#'
#' library(doParallel)
#' library(dtwclust)
#' k_clusters=2
#' registerDoParallel(cores=8)
#'
#' positive_clustering=tsclust(squiggles$positive,type="h",k=k_clusters,trace=TRUE,distance = "dtw_basic", control=hierarchical_control(method="ward.D",symmetric = T))
#'
#' cent=extract_centroids(positive_clustering)
#' ggplot(cent,aes(x=pos,y=signal,colour=factor(cluster)))+geom_point()+geom_line()+theme_minimal()+facet_grid(. ~ cluster)+guides(colour=guide_legend(title="cluster"))
#' @export
extract_centroids=function(tsclust_obj){
  centroids=tsclust_obj@centroids
  cul=unlist(centroids)
  cl=sapply(centroids,length)
  data.frame(signal=cul,cluster=rep(1:length(cl),cl),pos=unlist(sapply(centroids,function(x) 1:length(x))))
}

#' Obtain a series of tandem repeat unit clusters per sequencing read
#'
#' clusters_per_read() extracts the cluster per tandem repeat unit and 
#' concatenates them according to their original sequence in the sequencing
#' read.
#'
#' This function uses a tsclust object generated by dtwclust::tsclust() and
#' returns a data.frame containing a comma-separated series of tandem repeat
#' unit clusters.
#'
#' @param tsclust_obj A tsclust object generated by dtwclust::tsclust()
#' @examples
#' df <- load_summary("/storage/NanoSatellite_chunks/")
#' qc <- summary_qc(df)
#' df2 <- qual_reads(df,qc$center_cutoff)
#' squiggles <- load_squiggles("/storage/NanoSatellite_chunks/",df2)
#'
#' library(doParallel)
#' library(dtwclust)
#' k_clusters=2
#' registerDoParallel(cores=8)
#'
#' positive_clustering=tsclust(squiggles$positive,type="h",k=k_clusters,trace=TRUE,distance = "dtw_basic", control=hierarchical_control(method="ward.D",symmetric = T))
#'
#' cpr=clusters_per_read(positive_clustering)
#' @export
clusters_per_read=function(tsclust_obj){
  xxx=tsclust_obj@cluster
  yyy=strsplit(gsub("\\.chunk","",names(xxx)),"_")
  zzz=data.frame(name=sapply(yyy,function(x) x[1]),chunk_number=as.integer(sapply(yyy,function(x) x[3])),cluster=xxx,stringsAsFactors = F)
  zzz2=zzz[order(zzz$name,zzz$chunk_number),]
  zzz3=sapply(unique(zzz2$name),function(x) paste(zzz2[zzz2$name==x,"cluster"],collapse=","))
  data.frame(name=names(zzz3),clusters=zzz3,stringsAsFactors = F)
}


