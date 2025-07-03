//
//  LogsViewController.swift
//  nest-note
//

import UIKit
import Combine

class LogsViewController: UIViewController {
    private let tableView = UITableView()
    private var logs: [LogLine] = []
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupLogSubscription()
        fetchLogs()
    }
    
    private func setup() {
        title = "Logs"
        view.backgroundColor = .systemBackground
        
        // Setup TableView
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(LogCell.self, forCellReuseIdentifier: "LogCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        
        // Add refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshLogs), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        // Add clear button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Clear",
            style: .plain,
            target: self,
            action: #selector(clearLogs)
        )
    }
    
    private func setupLogSubscription() {
        Logger.shared.$lines
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchLogs()
            }
            .store(in: &cancellables)
    }
    
    private func fetchLogs() {
        logs = Logger.shared.lines.reversed()
        tableView.reloadData()
    }
    
    @objc private func refreshLogs() {
        fetchLogs()
        tableView.refreshControl?.endRefreshing()
    }
    
    @objc private func clearLogs() {
        let alert = UIAlertController(
            title: "Clear Logs",
            message: "Are you sure you want to clear all logs?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
//            Logger.clearLogs()
            self?.fetchLogs()
        })
        
        present(alert, animated: true)
    }
}

extension LogsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LogCell", for: indexPath) as! LogCell
        cell.configure(with: logs[indexPath.row])
        return cell
    }
}

private class LogCell: UITableViewCell {
    private let headerStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabel
        label.textAlignment = .left
        return label
    }()
    
    private let levelLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        label.textColor = .label
        label.textAlignment = .left
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()
    
    private let categoryLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .left
        return label
    }()
    
    private let contentLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .left
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        headerStackView.addArrangedSubview(levelLabel)
        headerStackView.addArrangedSubview(categoryLabel)
        headerStackView.addArrangedSubview(timestampLabel)
        
        contentView.addSubview(headerStackView)
        contentView.addSubview(contentLabel)
        
        NSLayoutConstraint.activate([
            headerStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            headerStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
            
            contentLabel.topAnchor.constraint(equalTo: headerStackView.bottomAnchor, constant: 4),
            contentLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            contentLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with log: LogLine) {
        timestampLabel.text = log.timestamp
        levelLabel.text = "[\(log.level.rawValue.uppercased())]"
        categoryLabel.text = "[\(log.category)]"
        contentLabel.text = log.content
        
        // Apply error styling for error logs
        if log.level == .error {
            backgroundColor = UIColor.red.withAlphaComponent(0.15)
            levelLabel.textColor = .red
        } else {
            backgroundColor = .clear
            levelLabel.textColor = .label
        }
    }
}
