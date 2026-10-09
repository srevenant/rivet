[
  [
    include: "pinky",
    prefix: 400
  ],
  [
    external: :app2,
    migrations: [
      [include: "yoink", prefix: 300]
    ]
  ]
]
