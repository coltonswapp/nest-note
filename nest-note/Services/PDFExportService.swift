import UIKit
import PDFKit
import CoreImage

class PDFExportService {
    
    // MARK: - PDF Section Types
    enum PDFSection {
        case entries
        case events
        case contacts
        case places
        case routines
    }
    
    // Default section order - easily customizable
    private static let defaultSectionOrder: [PDFSection] = [.events, .entries]
    
    static func generateSessionPDF(
        session: SessionItem,
        nestItem: NestItem,
        events: [SessionEvent] = [],
        selectedItemIds: [String]? = nil,
        sectionOrder: [PDFSection]? = nil
    ) async -> Data? {
        // Fetch all places from NestService and pre-load their images
        var allPlaces: [PlaceItem] = []
        var eventPlaces: [String: PlaceItem] = [:]
        var placeImages: [String: UIImage] = [:]
        do {
            allPlaces = try await NestService.shared.fetchPlaces()
            print("PDFExport: Fetched \(allPlaces.count) places from NestService")
            
            // Pre-load images for places that have thumbnails
            for place in allPlaces {
                eventPlaces[place.id] = place
                
                if place.thumbnailURLs != nil {
                    do {
                        let imageAsset = try await NestService.shared.loadImages(for: place)
                        // Force light mode for PDF export
                        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
                        let lightImage = imageAsset.imageAsset?.image(with: lightTraits) ?? imageAsset
                        placeImages[place.id] = lightImage
                        print("PDFExport: Loaded light mode image for place: \(place.displayName)")
                    } catch {
                        print("PDFExport: Failed to load image for place \(place.displayName): \(error)")
                        // Continue without image for this place
                    }
                }
            }
        } catch {
            print("PDFExport: Failed to fetch places: \(error)")
            // Continue without places if fetch fails
        }
        // Fetch entries from EntryRepository first
        var allEntries: [BaseEntry] = []
        do {
            let entriesByCategory = try await NestService.shared.fetchEntries()
            // Flatten the dictionary of [String: [BaseEntry]] to [BaseEntry]
            allEntries = entriesByCategory.values.flatMap { $0 }
            print("PDFExport: Fetched \(allEntries.count) entries from EntryRepository")
        } catch {
            print("PDFExport: Failed to fetch entries: \(error)")
            // Fallback to nestItem.entries if available
            allEntries = nestItem.entries ?? []
        }

        // Fetch routines
        var allRoutines: [RoutineItem] = []
        do {
            allRoutines = try await NestService.shared.fetchItems(ofType: .routine)
            print("PDFExport: Fetched \(allRoutines.count) routines from NestService")
        } catch {
            print("PDFExport: Failed to fetch routines: \(error)")
        }

        // Determine selection set: prefer explicit selectedItemIds, else session.entryIds, else empty
        let selectionSet: Set<String> = {
            if let explicit = selectedItemIds, !explicit.isEmpty {
                return Set(explicit)
            }
            if let sessionIds = session.entryIds, !sessionIds.isEmpty {
                return Set(sessionIds)
            }
            return []
        }()

        // Filter entries and places for the Entries section to ONLY selected items
        let filteredEntriesForEntriesSection: [BaseEntry] = allEntries.filter { selectionSet.contains($0.id) }
        let filteredPlacesForEntriesSection: [PlaceItem] = allPlaces.filter { selectionSet.contains($0.id) }
        let filteredRoutinesForSection: [RoutineItem] = allRoutines.filter { selectionSet.contains($0.id) }
        
        let pageSize = CGRect(x: 0, y: 0, width: 612, height: 792) // 8.5 x 11 inches at 72 DPI
        let renderer = UIGraphicsPDFRenderer(bounds: pageSize)
        
        let pdfData = renderer.pdfData { context in
            // Start the first page
            context.beginPage()
            let cgContext = context.cgContext
            
            var currentY: CGFloat = 60 // Top margin
            let leftMargin: CGFloat = 40
            let rightMargin: CGFloat = 40
            let contentWidth = pageSize.width - leftMargin - rightMargin
            
            // Draw header
            currentY = drawHeader(context: cgContext, session: session, pageSize: pageSize, leftMargin: leftMargin, rightMargin: rightMargin, currentY: currentY)
            
            // Draw horizontal line
            currentY += 20
            drawHorizontalLine(context: cgContext, y: currentY, leftMargin: leftMargin, rightMargin: rightMargin)
            currentY += 30
            
            // Use the provided section order or default
            let requestedSections = sectionOrder ?? defaultSectionOrder
            
            // Filter out sections that have no content
            let sectionsToRender = requestedSections.filter { section in
                switch section {
                case .events:
                    return !events.isEmpty
                case .entries:
                    return !filteredEntriesForEntriesSection.isEmpty || !filteredPlacesForEntriesSection.isEmpty || !filteredRoutinesForSection.isEmpty
                case .contacts:
                    return true // Always show contacts section for now
                case .places:
                    return !filteredPlacesForEntriesSection.isEmpty
                case .routines:
                    return !filteredRoutinesForSection.isEmpty
                }
            }
            
            // Draw sections in the specified order
            for (index, section) in sectionsToRender.enumerated() {
                let isFirstSection = index == 0
                
                // Add spacing between sections (except for the first one)
                if !isFirstSection {
                    currentY += 24
                }
                
                currentY = drawSection(
                    section: section,
                    context: context,
                    cgContext: cgContext,
                    session: session,
                    nestItem: nestItem,
                    allEntries: filteredEntriesForEntriesSection,
                    events: events,
                    eventPlaces: eventPlaces,
                    allPlaces: filteredPlacesForEntriesSection,
                    allRoutines: filteredRoutinesForSection,
                    placeImages: placeImages,
                    currentY: currentY,
                    leftMargin: leftMargin,
                    rightMargin: rightMargin,
                    contentWidth: contentWidth,
                    pageSize: pageSize
                )
                
                // Add half-width divider after each section (except the last one)
                if index < sectionsToRender.count - 1 {
                    currentY += 12
                    drawHalfWidthDivider(context: cgContext, y: currentY, leftMargin: leftMargin, contentWidth: contentWidth)
                    currentY += 24
                }
            }
        }
        
        return pdfData
    }
    
    private static func calculateSectionHeight(categoryName: String, entries: [BaseEntry], contentWidth: CGFloat) -> CGFloat {
        var totalHeight: CGFloat = 0
        
        // Category title height
        let categoryFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
        let categoryAttributes: [NSAttributedString.Key: Any] = [
            .font: categoryFont,
            .foregroundColor: UIColor.black
        ]
        let categorySize = categoryName.size(withAttributes: categoryAttributes)
        totalHeight += categorySize.height + 20 // title + spacing
        
        // Separate grid and full-width items
        let gridItems = entries.filter { isGridItem($0) }
        let fullWidthItems = entries.filter { !isGridItem($0) }
        
        // Calculate grid items height
        if !gridItems.isEmpty {
            let columnsPerRow = 3
            let rowHeight: CGFloat = 70
            let totalRows = (gridItems.count + columnsPerRow - 1) / columnsPerRow
            totalHeight += CGFloat(totalRows) * rowHeight + 16 // grid + spacing
        }
        
        // Calculate full-width items height
        for entry in fullWidthItems {
            // Title height
            let titleFont = UIFont.systemFont(ofSize: 12, weight: .medium)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.gray
            ]
            let titleSize = entry.title.uppercased().size(withAttributes: titleAttributes)
            totalHeight += titleSize.height + 8 // title + spacing
            
            // Content height (with text wrapping)
            let contentFont = UIFont.systemFont(ofSize: 14, weight: .regular)
            let contentAttributes: [NSAttributedString.Key: Any] = [
                .font: contentFont,
                .foregroundColor: UIColor.black
            ]
            
            let contentSize = entry.content.boundingRect(
                with: CGSize(width: contentWidth, height: 1000),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: contentAttributes,
                context: nil
            )
            
            totalHeight += contentSize.height + 16 // content + spacing between items
        }
        
        return totalHeight
    }
    
    private static func drawHeader(context: CGContext, session: SessionItem, pageSize: CGRect, leftMargin: CGFloat, rightMargin: CGFloat, currentY: CGFloat) -> CGFloat {
        var y = currentY
        
        // Session title
        let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        
        let titleText = session.title
        let titleSize = titleText.size(withAttributes: titleAttributes)
        titleText.draw(at: CGPoint(x: leftMargin, y: y), withAttributes: titleAttributes)
        y += titleSize.height + 8
        
        // Session dates
        let dateFont = UIFont.systemFont(ofSize: 16, weight: .regular)
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: UIColor.darkGray
        ]
        
        let dateFormatter = DateFormatter()
        let timeFormatter = DateFormatter()
        
        // Check if it's a single day session
        let calendar = Calendar.current
        let isSameDay = calendar.isDate(session.startDate, inSameDayAs: session.endDate)
        
        let dateText: String
        if isSameDay {
            // Same day: "Dec 17, 2025 • 5:45-7:45PM"
            dateFormatter.dateFormat = "MMM d, yyyy"
            timeFormatter.dateFormat = "h:mma"
            
            let startTime = timeFormatter.string(from: session.startDate)
            let endTime = timeFormatter.string(from: session.endDate)
            let dateString = dateFormatter.string(from: session.startDate)
            
            // Extract just the time part without AM/PM for start time
            let startTimeComponents = startTime.components(separatedBy: " ")
            let endTimeComponents = endTime.components(separatedBy: " ")
            
            if startTimeComponents.last == endTimeComponents.last {
                // Same AM/PM period: "5:45-7:45 PM"
                dateText = "\(dateString) • \(startTimeComponents[0])-\(endTime)"
            } else {
                // Different AM/PM periods: "11:45 AM-1:45 PM"
                dateText = "\(dateString) • \(startTime)-\(endTime)"
            }
        } else {
            // Multi-day: "Dec 17-19, 2025"
            dateFormatter.dateFormat = "MMM d"
            let startDay = dateFormatter.string(from: session.startDate)
            let endDay = dateFormatter.string(from: session.endDate)
            
            let yearFormatter = DateFormatter()
            yearFormatter.dateFormat = "yyyy"
            let year = yearFormatter.string(from: session.startDate)
            
            dateText = "\(startDay)-\(endDay), \(year)"
        }
        
        dateText.draw(at: CGPoint(x: leftMargin, y: y), withAttributes: dateAttributes)
        
        // Draw QR code with embedded logo
        let qrSize: CGFloat = 70
        let qrX = pageSize.width - rightMargin - qrSize
        let qrRect = CGRect(x: qrX, y: currentY, width: qrSize, height: qrSize)
        
        // Generate QR code with logo
        print("PDFExport: Attempting to load logo: \(NNImage.primaryLogo != nil ? "Success" : "Failed")")
        if let logoImage = NNImage.primaryLogo,
           let qrCodeImage = generateQRCodeWithLogo(text: "https://www.nestnoteapp.com", logo: logoImage) {
            print("PDFExport: QR code with logo generated successfully")
            
            // Save the current graphics state
            context.saveGState()
            
            // Flip the coordinate system to fix upside-down image
            context.translateBy(x: 0, y: qrRect.maxY)
            context.scaleBy(x: 1.0, y: -1.0)
            
            // Draw the QR code in the flipped coordinate system
            if let cgImage = qrCodeImage.cgImage {
                let flippedRect = CGRect(x: qrRect.minX, y: 0, width: qrRect.width, height: qrRect.height)
                context.draw(cgImage, in: flippedRect)
            }
            
            // Restore the graphics state
            context.restoreGState()
        } else {
            print("PDFExport: QR code generation failed, using fallback logo")
            // Fallback to simple logo if QR generation fails
            if let logoImage = UIImage(named: "NNImage.primaryLogo") {
                context.saveGState()
                context.translateBy(x: 0, y: qrRect.maxY)
                context.scaleBy(x: 1.0, y: -1.0)
                
                if let cgImage = logoImage.cgImage {
                    let flippedRect = CGRect(x: qrRect.minX, y: 0, width: qrRect.width, height: qrRect.height)
                    context.draw(cgImage, in: flippedRect)
                }
                
                context.restoreGState()
            }
        }
        
        return y + 20
    }
    
    private static func drawHorizontalLine(context: CGContext, y: CGFloat, leftMargin: CGFloat, rightMargin: CGFloat) {
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: leftMargin, y: y))
        context.addLine(to: CGPoint(x: 612 - rightMargin, y: y))
        context.strokePath()
    }
    
    private static func drawHalfWidthDivider(context: CGContext, y: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) {
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        let halfWidth = contentWidth / 2
        context.move(to: CGPoint(x: leftMargin, y: y))
        context.addLine(to: CGPoint(x: leftMargin + halfWidth, y: y))
        context.strokePath()
    }
    
    private static func drawCategorySectionWithPageBreaks(context: UIGraphicsPDFRendererContext, cgContext: CGContext, categoryName: String, entries: [BaseEntry], places: [PlaceItem], placeImages: [String: UIImage], currentY: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat, pageSize: CGRect) -> CGFloat {
        var y = currentY
        let bottomMargin: CGFloat = 60
        
        // Check if category title fits on current page
        let categoryFont = UIFont.systemFont(ofSize: 22, weight: .bold)
        let categoryAttributes: [NSAttributedString.Key: Any] = [
            .font: categoryFont,
            .foregroundColor: UIColor.black
        ]
        let categorySize = categoryName.size(withAttributes: categoryAttributes)
        let categoryHeight = categorySize.height + 20 // title + spacing
        
        if y + categoryHeight > pageSize.height - bottomMargin {
            context.beginPage()
            y = 60 // Reset to top margin
        }
        
        // Draw category title
        categoryName.draw(at: CGPoint(x: leftMargin, y: y), withAttributes: categoryAttributes)
        y += categoryHeight
        
        // Separate grid items from full-width items (entries only)
        let gridEntries = entries.filter { isGridItem($0) }
        let fullWidthItems = entries.filter { !isGridItem($0) }
        
        // Draw grid entries first (3-column layout)
        if !gridEntries.isEmpty {
            y = drawGridItemsWithPageBreaks(context: context, cgContext: cgContext, items: gridEntries, currentY: y, leftMargin: leftMargin, contentWidth: contentWidth, pageSize: pageSize, bottomMargin: bottomMargin)
            y += 16
        }
        
        // Draw places separately (2-item row layout)
        if !places.isEmpty {
            y = drawPlacesGridWithPageBreaks(context: context, cgContext: cgContext, places: places, placeImages: placeImages, currentY: y, leftMargin: leftMargin, contentWidth: contentWidth, pageSize: pageSize, bottomMargin: bottomMargin)
            y += 16
        }
        
        // Draw full-width items with page breaks
        for entry in fullWidthItems {
            y = drawFullWidthItemWithPageBreaks(context: context, cgContext: cgContext, entry: entry, currentY: y, leftMargin: leftMargin, contentWidth: contentWidth, pageSize: pageSize, bottomMargin: bottomMargin)
            y += 16
        }
        
        return y
    }
    
    private static func drawCategorySection(context: CGContext, categoryName: String, entries: [BaseEntry], currentY: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat, pageSize: CGRect) -> CGFloat {
        var y = currentY
        
        // Category title
        let categoryFont = UIFont.systemFont(ofSize: 22, weight: .bold)
        let categoryAttributes: [NSAttributedString.Key: Any] = [
            .font: categoryFont,
            .foregroundColor: UIColor.black
        ]
        
        let categorySize = categoryName.size(withAttributes: categoryAttributes)
        categoryName.draw(at: CGPoint(x: leftMargin, y: y), withAttributes: categoryAttributes)
        y += categorySize.height + 12
        
        // Separate grid items from full-width items
        let gridItems = entries.filter { isGridItem($0) }
        let fullWidthItems = entries.filter { !isGridItem($0) }
        
        // Draw grid items (2x2 layout)
        if !gridItems.isEmpty {
            y = drawGridItems(context: context, items: gridItems, currentY: y, leftMargin: leftMargin, contentWidth: contentWidth)
            y += 16
        }
        
        // Draw full-width items
        for entry in fullWidthItems {
            y = drawFullWidthItem(context: context, entry: entry, currentY: y, leftMargin: leftMargin, contentWidth: contentWidth)
            y += 16
        }
        
        return y
    }
    
    private static func isGridItem(_ entry: BaseEntry) -> Bool {
        // Use the same logic as the app: title ≤ 15 characters AND content ≤ 15 characters
        return entry.title.count <= 15 && entry.content.count <= 15
    }
    
    private static func drawGridItems(context: CGContext, items: [BaseEntry], currentY: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        let columnsPerRow = 3  // 3x3 grid
        let rowHeight: CGFloat = 70
        let columnWidth = contentWidth / CGFloat(columnsPerRow)
        let itemSpacing: CGFloat = 8  // Space between grid items
        
        var y = currentY
        
        for (index, item) in items.enumerated() {
            let row = index / columnsPerRow
            let column = index % columnsPerRow
            
            // Align with leftMargin (same as full-width items)
            let x = leftMargin + CGFloat(column) * columnWidth
            let itemY = y + CGFloat(row) * rowHeight
            
            // Calculate available width for this grid item (with spacing between items)
            let availableWidth = columnWidth - (column < columnsPerRow - 1 ? itemSpacing : 0)
            
            // Draw title - aligned to left edge (no padding)
            let titleFont = UIFont.systemFont(ofSize: 12, weight: .medium)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.gray
            ]
            
            let titleRect = CGRect(x: x, y: itemY + 8, width: availableWidth, height: 16)
            item.title.uppercased().draw(in: titleRect, withAttributes: titleAttributes)
            
            // Draw content - aligned to left edge (no padding)
            let contentFont = UIFont.systemFont(ofSize: 14, weight: .regular)
            let contentAttributes: [NSAttributedString.Key: Any] = [
                .font: contentFont,
                .foregroundColor: UIColor.black
            ]
            
            let contentRect = CGRect(x: x, y: itemY + 32, width: availableWidth, height: 30)
            item.content.draw(in: contentRect, withAttributes: contentAttributes)
        }
        
        let totalRows = (items.count + columnsPerRow - 1) / columnsPerRow
        return y + CGFloat(totalRows) * rowHeight
    }
    
    private static func drawFullWidthItem(context: CGContext, entry: BaseEntry, currentY: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var y = currentY
        
        // Draw title
        let titleFont = UIFont.systemFont(ofSize: 12, weight: .medium)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.gray
        ]
        
        let titleSize = entry.title.uppercased().size(withAttributes: titleAttributes)
        entry.title.uppercased().draw(at: CGPoint(x: leftMargin, y: y), withAttributes: titleAttributes)
        y += titleSize.height + 8
        
        // Draw content
        let contentFont = UIFont.systemFont(ofSize: 14, weight: .regular)
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: contentFont,
            .foregroundColor: UIColor.black
        ]
        
        let contentRect = CGRect(x: leftMargin, y: y, width: contentWidth, height: 1000) // Large height for automatic sizing
        let contentSize = entry.content.boundingRect(
            with: CGSize(width: contentWidth, height: 1000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: contentAttributes,
            context: nil
        )
        
        entry.content.draw(in: CGRect(x: leftMargin, y: y, width: contentWidth, height: contentSize.height), withAttributes: contentAttributes)
        
        return y + contentSize.height
    }
    
    private static func drawGridItemsWithPageBreaks(context: UIGraphicsPDFRendererContext, cgContext: CGContext, items: [BaseEntry], currentY: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat, pageSize: CGRect, bottomMargin: CGFloat) -> CGFloat {
        let columnsPerRow = 3
        let rowHeight: CGFloat = 70
        let columnWidth = contentWidth / CGFloat(columnsPerRow)
        let itemSpacing: CGFloat = 8
        
        var y = currentY
        var currentRowItems: [BaseEntry] = []
        
        for (index, item) in items.enumerated() {
            currentRowItems.append(item)
            
            // Check if we've completed a row or reached the end
            if currentRowItems.count == columnsPerRow || index == items.count - 1 {
                // Check if this row fits on the current page
                if y + rowHeight > pageSize.height - bottomMargin {
                    context.beginPage()
                    y = 60 // Reset to top margin
                }
                
                // Draw the current row
                for (columnIndex, rowItem) in currentRowItems.enumerated() {
                    let x = leftMargin + CGFloat(columnIndex) * columnWidth
                    let availableWidth = columnWidth - (columnIndex < columnsPerRow - 1 ? itemSpacing : 0)
                    
                    // Draw title
                    let titleFont = UIFont.systemFont(ofSize: 12, weight: .medium)
                    let titleAttributes: [NSAttributedString.Key: Any] = [
                        .font: titleFont,
                        .foregroundColor: UIColor.gray
                    ]
                    let titleRect = CGRect(x: x, y: y + 8, width: availableWidth, height: 16)
                    rowItem.title.uppercased().draw(in: titleRect, withAttributes: titleAttributes)
                    
                    // Draw content
                    let contentFont = UIFont.systemFont(ofSize: 14, weight: .regular)
                    let contentAttributes: [NSAttributedString.Key: Any] = [
                        .font: contentFont,
                        .foregroundColor: UIColor.black
                    ]
                    let contentRect = CGRect(x: x, y: y + 32, width: availableWidth, height: 30)
                    rowItem.content.draw(in: contentRect, withAttributes: contentAttributes)
                }
                
                y += rowHeight
                currentRowItems.removeAll()
            }
        }
        
        return y
    }
    
    private static func drawMixedGridItemsWithPageBreaks(context: UIGraphicsPDFRendererContext, cgContext: CGContext, items: [Any], placeImages: [String: UIImage], currentY: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat, pageSize: CGRect, bottomMargin: CGFloat) -> CGFloat {
        let columnsPerRow = 3
        let rowHeight: CGFloat = 90 // Increased to accommodate 80x80 places
        let columnWidth = contentWidth / CGFloat(columnsPerRow)
        let itemSpacing: CGFloat = 8
        
        var y = currentY
        var currentRowItems: [Any] = []
        
        for (index, item) in items.enumerated() {
            currentRowItems.append(item)
            
            // Check if we've completed a row or reached the end
            if currentRowItems.count == columnsPerRow || index == items.count - 1 {
                // Check if this row fits on the current page
                if y + rowHeight > pageSize.height - bottomMargin {
                    context.beginPage()
                    y = 60 // Reset to top margin
                }
                
                // Draw the current row
                for (columnIndex, rowItem) in currentRowItems.enumerated() {
                    let x = leftMargin + CGFloat(columnIndex) * columnWidth
                    let availableWidth = columnWidth - (columnIndex < columnsPerRow - 1 ? itemSpacing : 0)
                    
                    if let entry = rowItem as? BaseEntry {
                        // Draw entry item
                        let titleFont = UIFont.systemFont(ofSize: 12, weight: .medium)
                        let titleAttributes: [NSAttributedString.Key: Any] = [
                            .font: titleFont,
                            .foregroundColor: UIColor.gray
                        ]
                        let titleRect = CGRect(x: x, y: y + 8, width: availableWidth, height: 16)
                        entry.title.uppercased().draw(in: titleRect, withAttributes: titleAttributes)
                        
                        let contentFont = UIFont.systemFont(ofSize: 14, weight: .regular)
                        let contentAttributes: [NSAttributedString.Key: Any] = [
                            .font: contentFont,
                            .foregroundColor: UIColor.black
                        ]
                        let contentRect = CGRect(x: x, y: y + 32, width: availableWidth, height: 30)
                        entry.content.draw(in: contentRect, withAttributes: contentAttributes)
                        
                    } else if let place = rowItem as? PlaceItem {
                        // Draw place item with 80x80 thumbnail
                        drawSinglePlaceInGrid(
                            cgContext: cgContext,
                            place: place,
                            placeImages: placeImages,
                            itemX: x,
                            itemY: y,
                            itemWidth: availableWidth
                        )
                    }
                }
                
                y += rowHeight
                currentRowItems.removeAll()
            }
        }
        
        return y
    }
    
    private static func drawPlacesGridWithPageBreaks(context: UIGraphicsPDFRendererContext, cgContext: CGContext, places: [PlaceItem], placeImages: [String: UIImage], currentY: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat, pageSize: CGRect, bottomMargin: CGFloat) -> CGFloat {
        let itemsPerRow = 2 // 2-item row layout for places
        let rowHeight: CGFloat = 90 // Height for each place row
        let itemSpacing: CGFloat = 20 // Space between items in a row
        let itemWidth = (contentWidth - itemSpacing) / CGFloat(itemsPerRow)
        
        var y = currentY
        var currentRowItems: [PlaceItem] = []
        
        for (index, place) in places.enumerated() {
            currentRowItems.append(place)
            
            // Check if we've completed a row or reached the end
            if currentRowItems.count == itemsPerRow || index == places.count - 1 {
                // Check if this row fits on the current page
                if y + rowHeight > pageSize.height - bottomMargin {
                    context.beginPage()
                    y = 60 // Reset to top margin
                }
                
                // Draw the current row
                for (columnIndex, place) in currentRowItems.enumerated() {
                    let x = leftMargin + CGFloat(columnIndex) * (itemWidth + itemSpacing)
                    
                    // Draw place item with wider layout
                    drawSinglePlaceInGrid(
                        cgContext: cgContext,
                        place: place,
                        placeImages: placeImages,
                        itemX: x,
                        itemY: y,
                        itemWidth: itemWidth
                    )
                }
                
                y += rowHeight
                currentRowItems.removeAll()
            }
        }
        
        return y
    }
    
    private static func drawSinglePlaceInGrid(
        cgContext: CGContext,
        place: PlaceItem,
        placeImages: [String: UIImage],
        itemX: CGFloat,
        itemY: CGFloat,
        itemWidth: CGFloat
    ) {
        let thumbnailSize: CGFloat = 80 // Updated to 80x80
        let cornerRadius: CGFloat = 18 // 18pt corner radius
        let textMarginLeft: CGFloat = thumbnailSize + 12 // Space between thumbnail and text
        let availableTextWidth = itemWidth - textMarginLeft
        
        // Draw thumbnail with corner radius
        let thumbnailRect = CGRect(x: itemX, y: itemY, width: thumbnailSize, height: thumbnailSize)
        
        // Check if we have a pre-loaded image for this place
        if let thumbnailImage = placeImages[place.id] {
            // Save and restore graphics state for image drawing
            cgContext.saveGState()
            
            // Create a clipping path with rounded corners
            let path = UIBezierPath(roundedRect: thumbnailRect, cornerRadius: cornerRadius)
            cgContext.addPath(path.cgPath)
            cgContext.clip()
            
            // Flip coordinate system for proper image orientation
            cgContext.translateBy(x: 0, y: thumbnailRect.maxY)
            cgContext.scaleBy(x: 1.0, y: -1.0)
            
            // Draw the thumbnail image
            if let cgImage = thumbnailImage.cgImage {
                let flippedRect = CGRect(x: thumbnailRect.minX, y: 0, width: thumbnailRect.width, height: thumbnailRect.height)
                cgContext.draw(cgImage, in: flippedRect)
            }
            
            cgContext.restoreGState()
        } else {
            // Draw placeholder background with corner radius
            let path = UIBezierPath(roundedRect: thumbnailRect, cornerRadius: cornerRadius)
            cgContext.setFillColor(UIColor.lightGray.cgColor)
            cgContext.addPath(path.cgPath)
            cgContext.fillPath()
            
            cgContext.setStrokeColor(UIColor.gray.cgColor)
            cgContext.setLineWidth(1)
            cgContext.addPath(path.cgPath)
            cgContext.strokePath()
            
            // Draw mappin icon as placeholder
            let iconSize: CGFloat = 32 // Larger icon for 80x80 thumbnail
            let iconX = thumbnailRect.midX - iconSize/2
            let iconY = thumbnailRect.midY - iconSize/2
            
            cgContext.setFillColor(UIColor.darkGray.cgColor)
            
            // Draw circle for map pin
            let circleRect = CGRect(x: iconX + iconSize/4, y: iconY + iconSize/3, width: iconSize/2, height: iconSize/2)
            cgContext.fillEllipse(in: circleRect)
        }
        
        // Draw alias (name) to the right of thumbnail
        let nameFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: nameFont,
            .foregroundColor: UIColor.black
        ]
        
        let displayName = place.alias ?? place.displayName
        let nameRect = CGRect(x: itemX + textMarginLeft, y: itemY, width: availableTextWidth, height: 20)
        displayName.draw(in: nameRect, withAttributes: nameAttributes)
        
        // Draw address below the alias
        let addressFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        let addressAttributes: [NSAttributedString.Key: Any] = [
            .font: addressFont,
            .foregroundColor: UIColor.darkGray
        ]
        
        let addressRect = CGRect(x: itemX + textMarginLeft, y: itemY + 22, width: availableTextWidth, height: 58) // Remaining height
        place.address.draw(in: addressRect, withAttributes: addressAttributes)
    }
    
    private static func drawFullWidthItemWithPageBreaks(context: UIGraphicsPDFRendererContext, cgContext: CGContext, entry: BaseEntry, currentY: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat, pageSize: CGRect, bottomMargin: CGFloat) -> CGFloat {
        var y = currentY
        
        // Calculate the full height needed for this item
        let titleFont = UIFont.systemFont(ofSize: 12, weight: .medium)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.gray
        ]
        let titleSize = entry.title.uppercased().size(withAttributes: titleAttributes)
        
        let contentFont = UIFont.systemFont(ofSize: 14, weight: .regular)
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: contentFont,
            .foregroundColor: UIColor.black
        ]
        let contentSize = entry.content.boundingRect(
            with: CGSize(width: contentWidth, height: 1000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: contentAttributes,
            context: nil
        )
        
        let totalItemHeight = titleSize.height + 8 + contentSize.height
        
        // Check if the entire item fits on the current page
        if y + totalItemHeight > pageSize.height - bottomMargin {
            context.beginPage()
            y = 60 // Reset to top margin
        }
        
        // Draw title
        entry.title.uppercased().draw(at: CGPoint(x: leftMargin, y: y), withAttributes: titleAttributes)
        y += titleSize.height + 8
        
        // Draw content
        entry.content.draw(in: CGRect(x: leftMargin, y: y, width: contentWidth, height: contentSize.height), withAttributes: contentAttributes)
        y += contentSize.height
        
        return y
    }
    
    private static func generateQRCodeWithLogo(text: String, logo: UIImage) -> UIImage? {
        // Generate base QR code
        guard let data = text.data(using: String.Encoding.ascii),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Scale up the QR code for better quality
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        let qrImage = UIImage(cgImage: cgImage)
        
        // Add logo overlay
        let qrSize = qrImage.size
        let overlaySize = CGSize(width: qrSize.width * 0.3, height: qrSize.height * 0.3) // 35% of QR size
        
        let renderer = UIGraphicsImageRenderer(size: qrSize)
        let result = renderer.image { context in
            let cgContext = context.cgContext
            
            // Draw the QR code
            qrImage.draw(in: CGRect(origin: .zero, size: qrSize))
            
            // Calculate center position for overlay
            let overlayRect = CGRect(
                x: (qrSize.width - overlaySize.width) / 2,
                y: (qrSize.height - overlaySize.height) / 2,
                width: overlaySize.width,
                height: overlaySize.height
            )
            
            
            // Add white background behind the logo
            cgContext.setFillColor(UIColor.white.cgColor)
            let backgroundRect = overlayRect.insetBy(dx: -16, dy: -16)
            cgContext.addPath(UIBezierPath(roundedRect: backgroundRect, cornerRadius: overlaySize.height / 2).cgPath)
            cgContext.fillPath()
            
            // First create a properly sized version of the logo with color tint
            let logoRenderer = UIGraphicsImageRenderer(size: overlaySize)
            let resizedLogo = logoRenderer.image { context in
                let cgContext = context.cgContext
                
                // Set the tint color (change this to whatever color you want)
                cgContext.setFillColor(UIColor.black.cgColor)
                
                // Draw the logo as a mask and fill with color
                logo.draw(in: CGRect(origin: .zero, size: overlaySize))
                cgContext.setBlendMode(.sourceAtop)
                cgContext.fill(CGRect(origin: .zero, size: overlaySize))
            }
            
            // Draw the resized logo
            print("PDFExport: Original logo size: \(logo.size), overlay size: \(overlaySize)")
            resizedLogo.draw(in: overlayRect)
            print("PDFExport: Resized logo drawn in rect: \(overlayRect)")
        }
        
        return result
    }
    
    // MARK: - Section Drawing Router
    private static func drawSection(
        section: PDFSection,
        context: UIGraphicsPDFRendererContext,
        cgContext: CGContext,
        session: SessionItem,
        nestItem: NestItem,
        allEntries: [BaseEntry],
        events: [SessionEvent],
        eventPlaces: [String: PlaceItem],
        allPlaces: [PlaceItem],
        allRoutines: [RoutineItem],
        placeImages: [String: UIImage],
        currentY: CGFloat,
        leftMargin: CGFloat,
        rightMargin: CGFloat,
        contentWidth: CGFloat,
        pageSize: CGRect
    ) -> CGFloat {
        
        switch section {
        case .entries:
            return drawEntriesSection(
                context: context,
                cgContext: cgContext,
                allEntries: allEntries,
                allPlaces: allPlaces,
                allRoutines: allRoutines,
                placeImages: placeImages,
                currentY: currentY,
                leftMargin: leftMargin,
                contentWidth: contentWidth,
                pageSize: pageSize
            )
            
        case .events:
            return drawEventsSection(
                context: context,
                cgContext: cgContext,
                events: events,
                eventPlaces: eventPlaces,
                currentY: currentY,
                leftMargin: leftMargin,
                contentWidth: contentWidth,
                pageSize: pageSize
            )
            
        case .contacts:
            return drawContactsSection(
                context: context,
                cgContext: cgContext,
                session: session,
                currentY: currentY,
                leftMargin: leftMargin,
                contentWidth: contentWidth,
                pageSize: pageSize
            )
            
        case .places:
            return drawPlacesSection(
                context: context,
                cgContext: cgContext,
                allPlaces: allPlaces,
                placeImages: placeImages,
                currentY: currentY,
                leftMargin: leftMargin,
                contentWidth: contentWidth,
                pageSize: pageSize
            )
            
        case .routines:
            return drawRoutinesSection(
                context: context,
                cgContext: cgContext,
                routines: allRoutines,
                currentY: currentY,
                leftMargin: leftMargin,
                contentWidth: contentWidth,
                pageSize: pageSize
            )
        }
    }
    
    // MARK: - Individual Section Drawing Methods
    private static func drawEntriesSection(
        context: UIGraphicsPDFRendererContext,
        cgContext: CGContext,
        allEntries: [BaseEntry],
        allPlaces: [PlaceItem],
        allRoutines: [RoutineItem],
        placeImages: [String: UIImage],
        currentY: CGFloat,
        leftMargin: CGFloat,
        contentWidth: CGFloat,
        pageSize: CGRect
    ) -> CGFloat {
        
        var y = currentY
        
        // Use all entries regardless of visibility level
        print("PDFExport: Total entries: \(allEntries.count)")
        
        for entry in allEntries {
            print("PDFExport: Entry '\(entry.title)' - category: '\(entry.category)'")
        }
        
        // Group by category for unified folder rendering
        let entriesByCategory = Dictionary(grouping: allEntries) { $0.category }
        let placesByCategory = Dictionary(grouping: allPlaces) { $0.category }
        let routinesByCategory = Dictionary(grouping: allRoutines) { $0.category }
        let allCategories = Set(entriesByCategory.keys)
            .union(placesByCategory.keys)
            .union(routinesByCategory.keys)
        
        // Draw categories
        if allCategories.isEmpty {
            // Show a message if no entries are available
            let noEntriesFont = UIFont.systemFont(ofSize: 16, weight: .regular)
            let noEntriesAttributes: [NSAttributedString.Key: Any] = [
                .font: noEntriesFont,
                .foregroundColor: UIColor.gray
            ]
            let noEntriesText = "No entries or places available"
            noEntriesText.draw(at: CGPoint(x: leftMargin, y: y), withAttributes: noEntriesAttributes)
            y += noEntriesFont.lineHeight
        } else {
            let categories = allCategories.sorted()
            for (catIndex, categoryName) in categories.enumerated() {
                let entries = entriesByCategory[categoryName] ?? []
                let places = placesByCategory[categoryName] ?? []
                let routines = routinesByCategory[categoryName] ?? []

                if !entries.isEmpty || !places.isEmpty || !routines.isEmpty {
                    // Category header
                    let categoryFont = UIFont.systemFont(ofSize: 22, weight: .bold)
                    let categoryAttributes: [NSAttributedString.Key: Any] = [
                        .font: categoryFont,
                        .foregroundColor: UIColor.black
                    ]
                    let headerHeight = categoryName.size(withAttributes: categoryAttributes).height + 20
                    if y + headerHeight > pageSize.height - 60 {
                        context.beginPage(); y = 60
                    }
                    categoryName.draw(at: CGPoint(x: leftMargin, y: y), withAttributes: categoryAttributes)
                    y += headerHeight

                    // 1) Entries (grid then full-width)
                    let gridEntries = entries.filter { isGridItem($0) }
                    if !gridEntries.isEmpty {
                        y = drawGridItemsWithPageBreaks(
                            context: context,
                            cgContext: cgContext,
                            items: gridEntries,
                            currentY: y,
                            leftMargin: leftMargin,
                            contentWidth: contentWidth,
                            pageSize: pageSize,
                            bottomMargin: 60
                        )
                        y += 16
                    }
                    for entry in entries.filter({ !isGridItem($0) }) {
                        y = drawFullWidthItemWithPageBreaks(
                            context: context,
                            cgContext: cgContext,
                            entry: entry,
                            currentY: y,
                            leftMargin: leftMargin,
                            contentWidth: contentWidth,
                            pageSize: pageSize,
                            bottomMargin: 60
                        )
                        y += 16
                    }

                    // 2) Places (2 per row) with extra padding from entries
                    if !places.isEmpty {
                        // Extra top padding before places to reduce cramping with entries above
                        y += 12
                        y = drawPlacesGridWithPageBreaks(
                            context: context,
                            cgContext: cgContext,
                            places: places,
                            placeImages: placeImages,
                            currentY: y,
                            leftMargin: leftMargin,
                            contentWidth: contentWidth,
                            pageSize: pageSize,
                            bottomMargin: 60
                        )
                        // Extra bottom padding after places before routines
                        y += 24
                    }

                    // 3) Routines (checklist)
                    if !routines.isEmpty {
                        y = drawRoutineCategory(
                            context: context,
                            cgContext: cgContext,
                            categoryName: "", // no nested header inside category
                            routines: routines,
                            currentY: y,
                            leftMargin: leftMargin,
                            contentWidth: contentWidth,
                            pageSize: pageSize,
                            bottomMargin: 60
                        )
                        y += 8
                    }
                    // Divider between folders (categories)
                    if catIndex < categories.count - 1 {
                        y += 12
                        drawHalfWidthDivider(context: cgContext, y: y, leftMargin: leftMargin, contentWidth: contentWidth)
                        y += 24
                    }
                }
            }
        }
        
        return y
    }
    
    private static func drawEventsSection(context: UIGraphicsPDFRendererContext, cgContext: CGContext, events: [SessionEvent], eventPlaces: [String: PlaceItem], currentY: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat, pageSize: CGRect) -> CGFloat {
        var y = currentY
        let bottomMargin: CGFloat = 60
        
        // Events section title
        let titleFont = UIFont.systemFont(ofSize: 22, weight: .bold)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        
        let titleHeight = "Events".size(withAttributes: titleAttributes).height + 20
        
        // Check if title fits
        if y + titleHeight > pageSize.height - bottomMargin {
            context.beginPage()
            y = 60
        }
        
        "Events".draw(at: CGPoint(x: leftMargin, y: y), withAttributes: titleAttributes)
        y += titleHeight
        
        // Group events by date
        let groupedEvents = groupEventsByDate(events)
        
        // Draw events grouped by date
        for (dateString, dayEvents) in groupedEvents.sorted(by: { $0.key < $1.key }) {
            y = drawEventDateGroup(
                context: context,
                cgContext: cgContext,
                dateString: dateString,
                events: dayEvents,
                eventPlaces: eventPlaces,
                currentY: y,
                leftMargin: leftMargin,
                contentWidth: contentWidth,
                pageSize: pageSize,
                bottomMargin: bottomMargin
            )
            y += 16 // Space between date groups
        }
        
        return y
    }
    
    private static func groupEventsByDate(_ events: [SessionEvent]) -> [String: [SessionEvent]] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, MMM d, yyyy"
        
        var grouped: [String: [SessionEvent]] = [:]
        
        for event in events.sorted(by: { $0.startDate < $1.startDate }) {
            let dateKey = dateFormatter.string(from: event.startDate)
            if grouped[dateKey] == nil {
                grouped[dateKey] = []
            }
            grouped[dateKey]?.append(event)
        }
        
        return grouped
    }
    
    private static func drawEventDateGroup(context: UIGraphicsPDFRendererContext, cgContext: CGContext, dateString: String, events: [SessionEvent], eventPlaces: [String: PlaceItem], currentY: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat, pageSize: CGRect, bottomMargin: CGFloat) -> CGFloat {
        var y = currentY
        
        // Date header
        let dateFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: UIColor.black
        ]
        
        let dateHeight = dateString.size(withAttributes: dateAttributes).height + 16
        
        // Check if date header fits
        if y + dateHeight > pageSize.height - bottomMargin {
            context.beginPage()
            y = 60
        }
        
        dateString.draw(at: CGPoint(x: leftMargin, y: y), withAttributes: dateAttributes)
        y += dateHeight
        
        // Draw events for this date
        for event in events.sorted(by: { $0.startDate < $1.startDate }) {
            let eventHeight = calculateEventHeight(event: event, contentWidth: contentWidth)
            
            // Check if event fits on current page
            if y + eventHeight > pageSize.height - bottomMargin {
                context.beginPage()
                y = 60
            }
            
            y = drawSingleEvent(
                cgContext: cgContext,
                event: event,
                eventPlaces: eventPlaces,
                currentY: y,
                leftMargin: leftMargin,
                contentWidth: contentWidth
            )
            y += 12 // Space between events
        }
        
        return y
    }
    
    private static func calculateEventHeight(event: SessionEvent, contentWidth: CGFloat) -> CGFloat {
        let titleFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
        let detailFont = UIFont.systemFont(ofSize: 14, weight: .regular)
        
        let titleHeight = event.title.size(withAttributes: [.font: titleFont]).height
        let timeHeight = "12:00 PM - 1:00 PM".size(withAttributes: [.font: detailFont]).height
        let placeHeight = "Sample Place Name\n123 Main St".size(withAttributes: [.font: detailFont]).height
        
        return titleHeight + timeHeight + placeHeight + 24 // padding
    }
    
    private static func drawSingleEvent(cgContext: CGContext, event: SessionEvent, eventPlaces: [String: PlaceItem], currentY: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        let startY = currentY
        var y = currentY
        let eventContentX = leftMargin + 8 // Align with entries and categories
        let lineSpacing: CGFloat = 4 // Consistent spacing between elements
        
        // Event title
        let titleFont = UIFont.systemFont(ofSize: 14, weight: .medium)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.gray
        ]
        
        event.title.uppercased().draw(at: CGPoint(x: eventContentX, y: y), withAttributes: titleAttributes)
        y += titleFont.lineHeight + lineSpacing
        
        // Event time
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let startTime = timeFormatter.string(from: event.startDate)
        let endTime = timeFormatter.string(from: event.endDate)
        let timeString = "\(startTime) - \(endTime)"
        
        let contentFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: contentFont,
            .foregroundColor: UIColor.black
        ]
        
        timeString.draw(at: CGPoint(x: eventContentX, y: y), withAttributes: contentAttributes)
        y += contentFont.lineHeight + lineSpacing
        
        // Place lookup and display
        if let placeID = event.placeID, !placeID.isEmpty, let place = eventPlaces[placeID] {
            // Draw place name (displayName uses alias if available, otherwise first part of address)
            place.displayName.draw(at: CGPoint(x: eventContentX, y: y), withAttributes: contentAttributes)
            y += contentFont.lineHeight + lineSpacing
            
            // Draw address
            let addressAttributes: [NSAttributedString.Key: Any] = [
                .font: contentFont,
                .foregroundColor: UIColor.darkGray
            ]
            place.address.draw(at: CGPoint(x: eventContentX, y: y), withAttributes: addressAttributes)
            y += contentFont.lineHeight
        }
        
        // Draw vertical line aligned with horizontal margin
        let lineX = leftMargin // Align with the margin, not offset
        let lineHeight = y - startY
        
        // Use the event's associated color
        let eventColor = event.eventColor.border
        cgContext.setStrokeColor(eventColor.cgColor)
        cgContext.setLineWidth(3)
        cgContext.move(to: CGPoint(x: lineX, y: startY))
        cgContext.addLine(to: CGPoint(x: lineX, y: startY + lineHeight))
        cgContext.strokePath()
        
        return y
    }
    
    // MARK: - Future Section Methods (Placeholder implementations)
    private static func drawContactsSection(
        context: UIGraphicsPDFRendererContext,
        cgContext: CGContext,
        session: SessionItem,
        currentY: CGFloat,
        leftMargin: CGFloat,
        contentWidth: CGFloat,
        pageSize: CGRect
    ) -> CGFloat {
        // TODO: Implement contacts section
        // Could show assigned sitter contact info, emergency contacts, etc.
        return currentY
    }
    
    private static func drawPlacesSection(
        context: UIGraphicsPDFRendererContext,
        cgContext: CGContext,
        allPlaces: [PlaceItem],
        placeImages: [String: UIImage],
        currentY: CGFloat,
        leftMargin: CGFloat,
        contentWidth: CGFloat,
        pageSize: CGRect
    ) -> CGFloat {
        var y = currentY
        let bottomMargin: CGFloat = 60
        
        // Skip empty places section
        guard !allPlaces.isEmpty else {
            return y
        }
        
        // Section title
        let titleFont = UIFont.systemFont(ofSize: 22, weight: .bold)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        
        let titleHeight = "Places".size(withAttributes: titleAttributes).height + 20
        
        // Check if title fits
        if y + titleHeight > pageSize.height - bottomMargin {
            context.beginPage()
            y = 60
        }
        
        "Places".draw(at: CGPoint(x: leftMargin, y: y), withAttributes: titleAttributes)
        y += titleHeight
        
        // Draw places in 2-item row grid
        y = drawPlacesGrid(
            context: context,
            cgContext: cgContext,
            places: allPlaces,
            placeImages: placeImages,
            currentY: y,
            leftMargin: leftMargin,
            contentWidth: contentWidth,
            pageSize: pageSize,
            bottomMargin: bottomMargin
        )
        
        return y
    }
    
    private static func drawPlacesGrid(
        context: UIGraphicsPDFRendererContext,
        cgContext: CGContext,
        places: [PlaceItem],
        placeImages: [String: UIImage],
        currentY: CGFloat,
        leftMargin: CGFloat,
        contentWidth: CGFloat,
        pageSize: CGRect,
        bottomMargin: CGFloat
    ) -> CGFloat {
        let itemsPerRow = 2
        let rowHeight: CGFloat = 80 // Height for each place row
        let itemSpacing: CGFloat = 20 // Space between items in a row
        let itemWidth = (contentWidth - itemSpacing) / CGFloat(itemsPerRow)
        let thumbnailSize: CGFloat = 60 // 1x1 aspect ratio square
        
        var y = currentY
        
        for (index, place) in places.enumerated() {
            let row = index / itemsPerRow
            let column = index % itemsPerRow
            
            // Check if we need a new page for this row
            if column == 0 { // First item in row
                if y + rowHeight > pageSize.height - bottomMargin {
                    context.beginPage()
                    y = 60 // Reset to top margin
                }
            }
            
            // Calculate position for this item
            let itemX = leftMargin + CGFloat(column) * (itemWidth + itemSpacing)
            let itemY = y + CGFloat(row - (index / itemsPerRow == 0 ? 0 : index / itemsPerRow)) * rowHeight
            
            // Draw place item
            drawSinglePlace(
                cgContext: cgContext,
                place: place,
                placeImages: placeImages,
                itemX: itemX,
                itemY: itemY,
                itemWidth: itemWidth,
                thumbnailSize: thumbnailSize
            )
            
            // Update y position after completing a row or at the end
            if column == itemsPerRow - 1 || index == places.count - 1 {
                y += rowHeight
            }
        }
        
        return y
    }
    
    private static func drawSinglePlace(
        cgContext: CGContext,
        place: PlaceItem,
        placeImages: [String: UIImage],
        itemX: CGFloat,
        itemY: CGFloat,
        itemWidth: CGFloat,
        thumbnailSize: CGFloat
    ) {
        let textMarginLeft: CGFloat = thumbnailSize + 12 // Space between thumbnail and text
        let availableTextWidth = itemWidth - textMarginLeft
        
        // Draw thumbnail
        let thumbnailRect = CGRect(x: itemX, y: itemY, width: thumbnailSize, height: thumbnailSize)
        
        // Check if we have a pre-loaded image for this place
        if let thumbnailImage = placeImages[place.id] {
            // Save and restore graphics state for image drawing
            cgContext.saveGState()
            
            // Flip coordinate system for proper image orientation
            cgContext.translateBy(x: 0, y: thumbnailRect.maxY)
            cgContext.scaleBy(x: 1.0, y: -1.0)
            
            // Draw the thumbnail image
            if let cgImage = thumbnailImage.cgImage {
                let flippedRect = CGRect(x: thumbnailRect.minX, y: 0, width: thumbnailRect.width, height: thumbnailRect.height)
                cgContext.draw(cgImage, in: flippedRect)
            }
            
            cgContext.restoreGState()
        } else {
            // Draw placeholder background and border if no image available
            cgContext.setFillColor(UIColor.lightGray.cgColor)
            cgContext.fill(thumbnailRect)
            
            cgContext.setStrokeColor(UIColor.gray.cgColor)
            cgContext.setLineWidth(1)
            cgContext.stroke(thumbnailRect)
            
            // Draw mappin icon as placeholder
            let iconSize: CGFloat = 24
            let iconX = thumbnailRect.midX - iconSize/2
            let iconY = thumbnailRect.midY - iconSize/2
            
            cgContext.setFillColor(UIColor.darkGray.cgColor)
            
            // Draw circle for map pin
            let circleRect = CGRect(x: iconX + iconSize/4, y: iconY + iconSize/3, width: iconSize/2, height: iconSize/2)
            cgContext.fillEllipse(in: circleRect)
        }
        
        // Draw name (alias or display name)
        let nameFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: nameFont,
            .foregroundColor: UIColor.black
        ]
        
        let displayName = place.alias ?? place.displayName
        let nameRect = CGRect(x: itemX + textMarginLeft, y: itemY, width: availableTextWidth, height: 20)
        displayName.draw(in: nameRect, withAttributes: nameAttributes)
        
        // Draw address
        let addressFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        let addressAttributes: [NSAttributedString.Key: Any] = [
            .font: addressFont,
            .foregroundColor: UIColor.darkGray
        ]
        
        let addressRect = CGRect(x: itemX + textMarginLeft, y: itemY + 22, width: availableTextWidth, height: 40)
        place.address.draw(in: addressRect, withAttributes: addressAttributes)
    }
    
    private static func drawRoutinesSection(
        context: UIGraphicsPDFRendererContext,
        cgContext: CGContext,
        routines: [RoutineItem],
        currentY: CGFloat,
        leftMargin: CGFloat,
        contentWidth: CGFloat,
        pageSize: CGRect
    ) -> CGFloat {
        var y = currentY
        let bottomMargin: CGFloat = 60
        guard !routines.isEmpty else { return y }

        // Section title
        let titleFont = UIFont.systemFont(ofSize: 22, weight: .bold)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        let titleHeight = "Routines".size(withAttributes: titleAttributes).height + 20
        if y + titleHeight > pageSize.height - bottomMargin {
            context.beginPage(); y = 60
        }
        "Routines".draw(at: CGPoint(x: leftMargin, y: y), withAttributes: titleAttributes)
        y += titleHeight

        // Group routines by category for consistency with entries
        let routinesByCategory = Dictionary(grouping: routines) { $0.category }
        for category in routinesByCategory.keys.sorted() {
            let categoryRoutines = routinesByCategory[category] ?? []
            y = drawRoutineCategory(
                context: context,
                cgContext: cgContext,
                categoryName: category,
                routines: categoryRoutines,
                currentY: y,
                leftMargin: leftMargin,
                contentWidth: contentWidth,
                pageSize: pageSize,
                bottomMargin: bottomMargin
            )
            y += 16
        }

        return y
    }

    private static func drawRoutineCategory(
        context: UIGraphicsPDFRendererContext,
        cgContext: CGContext,
        categoryName: String,
        routines: [RoutineItem],
        currentY: CGFloat,
        leftMargin: CGFloat,
        contentWidth: CGFloat,
        pageSize: CGRect,
        bottomMargin: CGFloat
    ) -> CGFloat {
        var y = currentY

        // Category title
        let categoryFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
        let categoryAttributes: [NSAttributedString.Key: Any] = [
            .font: categoryFont,
            .foregroundColor: UIColor.black
        ]
        let categoryHeight = categoryName.size(withAttributes: categoryAttributes).height + 12
        if y + categoryHeight > pageSize.height - bottomMargin {
            context.beginPage(); y = 60
        }
        categoryName.draw(at: CGPoint(x: leftMargin, y: y), withAttributes: categoryAttributes)
        y += categoryHeight

        // Each routine
        for routine in routines {
            // Routine title
            let routineTitleFont = UIFont.systemFont(ofSize: 14, weight: .medium)
            let routineTitleAttrs: [NSAttributedString.Key: Any] = [
                .font: routineTitleFont,
                .foregroundColor: UIColor.gray
            ]
            let routineTitleHeight = routine.title.uppercased().size(withAttributes: routineTitleAttrs).height
            if y + routineTitleHeight > pageSize.height - bottomMargin {
                context.beginPage(); y = 60
            }
            routine.title.uppercased().draw(at: CGPoint(x: leftMargin, y: y), withAttributes: routineTitleAttrs)
            y += routineTitleHeight + 6

            // Actions list with bullet (circle)
            let actionFont = UIFont.systemFont(ofSize: 14, weight: .regular)
            let actionAttrs: [NSAttributedString.Key: Any] = [
                .font: actionFont,
                .foregroundColor: UIColor.black
            ]
            let bulletSize: CGFloat = 4
            let bulletSpacing: CGFloat = 8
            let actionLineSpacing: CGFloat = 6
            let actionIndentX = leftMargin + bulletSize + bulletSpacing + 4
            for action in routine.routineActions {
                let lineHeight = max(bulletSize, actionFont.lineHeight)
                if y + lineHeight > pageSize.height - bottomMargin {
                    context.beginPage(); y = 60
                }

                // Draw circular bullet
                let bulletRect = CGRect(x: leftMargin, y: y + (lineHeight - bulletSize) / 2, width: bulletSize, height: bulletSize)
                cgContext.setFillColor(UIColor.black.cgColor)
                cgContext.fillEllipse(in: bulletRect)

                // Draw action text
                let actionPoint = CGPoint(x: actionIndentX, y: y)
                (action as NSString).draw(at: actionPoint, withAttributes: actionAttrs)

                y += lineHeight + actionLineSpacing
            }

            y += 8 // spacing between routines
        }

        return y
    }
}
